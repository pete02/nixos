
import logging
import os
import re
import subprocess
import sys
import time

from evdev import UInput, ecodes as e

CEC_DEVICE = "@CEC_DEVICE@"
CEC_CTL = "@CEC_CTL@"
STDBUF = "@STDBUF@"
PEGASUS_SERVICE = "@PEGASUS_SERVICE@"
MOUSE_ON_KEY = "@MOUSE_ON_KEY@"
MOUSE_OFF_KEY = "@MOUSE_OFF_KEY@"
# Keep the virtual pointer around for the whole run instead of creating it when
# mouse mode is switched on. Costs a permanently visible cursor, saves the
# device hotplug delay.
PERSISTENT_POINTER = "@PERSISTENT_POINTER@" == "1"
MULTITAP_TIMEOUT = 0.9

# Mouse mode tuning: pixels per key press, growing while a direction is
# held/repeated (presses of the same direction within MOUSE_REPEAT_WINDOW).
MOUSE_BASE_STEP = 10
MOUSE_MAX_STEP = 80
MOUSE_ACCEL = 5
MOUSE_REPEAT_WINDOW = 0.4
# A freshly created pointer is only usable once udev has processed it and the
# compositor has opened it. Wait for udev (up to MOUSE_READY_TIMEOUT), then give
# the compositor MOUSE_SETTLE to pick the device up. Events sent before that
# are silently dropped, which looks like input lag.
MOUSE_READY_TIMEOUT = 2.0
MOUSE_SETTLE = 0.05
UDEV_DATA_DIR = "/run/udev/data"

# Warn when a CEC message sat this long between the kernel receiving it and
# this script seeing it. Anything above this means the lag is on our side.
LATENCY_WARN = 0.15

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

KEYS = {
    e.KEY_ENTER,
    e.KEY_ESC,
    e.KEY_UP,
    e.KEY_RIGHT,
    e.KEY_DOWN,
    e.KEY_LEFT,
    e.KEY_BACKSPACE,
    e.KEY_SPACE,
    e.KEY_DOT,
    e.KEY_COMMA,
    e.KEY_SLASH,
    e.KEY_1,
    e.KEY_0,
    e.KEY_LEFTSHIFT,
}
KEYS.update(getattr(e, f"KEY_{letter.upper()}") for letter in "abcdefghijklmnopqrstuvwxyz")

keyboard = UInput(
    {e.EV_KEY: sorted(KEYS)},
    name="HDMI-CEC Remote",
)

# The pointer is a separate, on-demand device so the compositor only shows a
# cursor while mouse mode is active.
mouse = None
mouse_mode = False
last_direction = None
direction_streak = 0
last_move = 0.0

KEY_MAP = {
    "select": e.KEY_ENTER,
    "up": e.KEY_UP,
    "right": e.KEY_RIGHT,
    "down": e.KEY_DOWN,
    "left": e.KEY_LEFT,
    "back": e.KEY_ESC,
    "data": e.KEY_BACKSPACE,
}

MOUSE_DIRECTIONS = {
    "up": (0, -1),
    "down": (0, 1),
    "left": (-1, 0),
    "right": (1, 0),
}

DIGITS = {
    "number-1": "1",
    "number-2": "2",
    "number-3": "3",
    "number-4": "4",
    "number-5": "5",
    "number-6": "6",
    "number-7": "7",
    "number-8": "8",
    "number-9": "9",
    "number-0-or-number-10": "0",
}

MULTITAP = {
    "1": ".,?!1",
    "2": "abc",
    "3": "def",
    "4": "ghi",
    "5": "jkl",
    "6": "mno",
    "7": "pqrs",
    "8": "tuv",
    "9": "wxyz",
    "0": " 0",
}

CHAR_KEYS = {
    " ": e.KEY_SPACE,
    ".": e.KEY_DOT,
    ",": e.KEY_COMMA,
    "?": e.KEY_SLASH,
    "!": e.KEY_1,
    "1": e.KEY_1,
    "0": e.KEY_0,
}
CHAR_KEYS.update({
    letter: getattr(e, f"KEY_{letter.upper()}")
    for letter in "abcdefghijklmnopqrstuvwxyz"
})

last_digit = None
last_index = 0
last_press = 0.0


def tap(code):
    keyboard.write(e.EV_KEY, code, 1)
    keyboard.syn()
    keyboard.write(e.EV_KEY, code, 0)
    keyboard.syn()


def type_character(char):
    code = CHAR_KEYS[char]
    shifted = char in "?!"

    if shifted:
        keyboard.write(e.EV_KEY, e.KEY_LEFTSHIFT, 1)

    keyboard.write(e.EV_KEY, code, 1)
    keyboard.syn()

    keyboard.write(e.EV_KEY, code, 0)

    if shifted:
        keyboard.write(e.EV_KEY, e.KEY_LEFTSHIFT, 0)

    keyboard.syn()


def reset_multitap():
    global last_digit, last_index, last_press
    last_digit = None
    last_index = 0
    last_press = 0.0


def type_digit(digit):
    global last_digit, last_index, last_press

    now = time.monotonic()

    if last_digit == digit and now - last_press <= MULTITAP_TIMEOUT:
        tap(e.KEY_BACKSPACE)
        last_index = (last_index + 1) % len(MULTITAP[digit])
    else:
        last_index = 0

    type_character(MULTITAP[digit][last_index])

    last_digit = digit
    last_press = now


def wait_for_udev(device):
    """Wait until udev has finished processing a new input device.

    The compositor only learns about the device from udev's "add" event, which
    is sent after the rules ran and the device database entry was written. A
    fixed sleep either wastes time or is too short on a busy machine.
    """
    try:
        rdev = os.stat(device.path).st_rdev
        entry = f"{UDEV_DATA_DIR}/c{os.major(rdev)}:{os.minor(rdev)}"
    except (OSError, AttributeError):
        time.sleep(0.3)
        return False

    deadline = time.monotonic() + MOUSE_READY_TIMEOUT
    while time.monotonic() < deadline:
        try:
            with open(entry, encoding="utf-8", errors="replace") as db:
                if "ID_INPUT=1" in db.read():
                    return True
        except OSError:
            pass
        time.sleep(0.01)

    return False


def create_mouse():
    global mouse

    if mouse is not None:
        return True

    started = time.monotonic()
    try:
        mouse = UInput(
            {
                e.EV_KEY: [e.BTN_LEFT],
                e.EV_REL: [e.REL_X, e.REL_Y],
            },
            name="HDMI-CEC Mouse",
        )
    except OSError:
        logging.exception("Could not create the virtual mouse")
        return False

    ready = wait_for_udev(mouse.device)
    time.sleep(MOUSE_SETTLE)
    logging.info(
        "Virtual mouse ready after %.0f ms%s",
        (time.monotonic() - started) * 1000,
        "" if ready else " (udev did not confirm it, continuing anyway)",
    )
    return True


def enable_mouse_mode():
    global mouse_mode, last_direction, direction_streak

    if not create_mouse():
        return

    last_direction = None
    direction_streak = 0
    mouse_mode = True
    logging.info("Mouse mode on")


def disable_mouse_mode():
    global mouse, mouse_mode

    mouse_mode = False

    if mouse is not None and not PERSISTENT_POINTER:
        mouse.close()
        mouse = None
    logging.info("Mouse mode off")


def move_mouse(direction):
    global last_direction, direction_streak, last_move

    now = time.monotonic()

    if direction == last_direction and now - last_move <= MOUSE_REPEAT_WINDOW:
        direction_streak += 1
    else:
        direction_streak = 0

    last_direction = direction
    last_move = now

    step = min(MOUSE_MAX_STEP, MOUSE_BASE_STEP + direction_streak * MOUSE_ACCEL)
    dx, dy = MOUSE_DIRECTIONS[direction]

    if dx:
        mouse.write(e.EV_REL, e.REL_X, dx * step)
    if dy:
        mouse.write(e.EV_REL, e.REL_Y, dy * step)
    mouse.syn()


def click_mouse():
    mouse.write(e.EV_KEY, e.BTN_LEFT, 1)
    mouse.syn()
    mouse.write(e.EV_KEY, e.BTN_LEFT, 0)
    mouse.syn()


def return_to_pegasus():
    reset_multitap()
    disable_mouse_mode()
    logging.info("Returning to Pegasus by restarting %s", PEGASUS_SERVICE)
    # --no-block: the restart can take seconds, and every CEC message that
    # arrives meanwhile would wait behind it.
    subprocess.run(
        ["systemctl", "restart", "--no-block", PEGASUS_SERVICE],
        check=False,
        timeout=30,
    )


def handle_command(command):
    if command == MOUSE_ON_KEY:
        reset_multitap()
        enable_mouse_mode()
        return

    if command == MOUSE_OFF_KEY:
        reset_multitap()
        disable_mouse_mode()
        return

    if mouse_mode:
        if command in MOUSE_DIRECTIONS:
            move_mouse(command)
            return

        if command == "select":
            click_mouse()
            logging.debug("Click")
            return

    if command in KEY_MAP:
        reset_multitap()
        tap(KEY_MAP[command])
        logging.debug("Key: %s", command)
        return

    if command in DIGITS:
        digit = DIGITS[command]
        type_digit(digit)
        logging.debug("Digit: %s", digit)
        return

    if command == "electronic-program-guide":
        return_to_pegasus()
        return

    logging.debug("Ignoring CEC command: %s", command)


RX_TIMESTAMP = re.compile(r"Rx Timestamp:\s+(\d+\.\d+)s")


def report_latency(rx_ts):
    """Log how long ago the kernel received the message that was just read."""
    lag = time.monotonic() - rx_ts

    if lag > LATENCY_WARN:
        logging.warning(
            "CEC message reached the listener %.0f ms after the kernel got it",
            lag * 1000,
        )
    else:
        logging.debug("CEC message latency %.0f ms", lag * 1000)


def main():
    command = [
        STDBUF,
        "-oL",
        CEC_CTL,
        "-d",
        CEC_DEVICE,
        "--monitor",
        # Adds an "Rx Timestamp" line per message (kernel receive time on
        # CLOCK_MONOTONIC), used to measure how late we see each message.
        "--verbose",
    ]

    logging.info("Starting CEC listener on %s", CEC_DEVICE)

    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    try:
        if PERSISTENT_POINTER:
            create_mouse()

        for line in process.stdout:
            match = re.search(r"ui-cmd:\s+([a-z0-9-]+)", line)
            if match:
                handle_command(match.group(1))
                continue

            stamp = RX_TIMESTAMP.search(line)
            if stamp:
                report_latency(float(stamp.group(1)))
            elif line.strip():
                logging.debug("CEC: %s", line.strip())

    finally:
        process.terminate()
        process.wait()

    raise RuntimeError("cec-ctl exited unexpectedly")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        logging.exception("HDMI-CEC listener failed")
        sys.exit(1)
