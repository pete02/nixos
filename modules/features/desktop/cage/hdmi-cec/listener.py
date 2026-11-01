import logging
import re
import subprocess
import sys
import time

from evdev import UInput, ecodes as e

CEC_DEVICE = "@CEC_DEVICE@"
CEC_CTL = "@CEC_CTL@"
STDBUF = "@STDBUF@"
PEGASUS_SERVICE = "@PEGASUS_SERVICE@"
MOUSE_TOGGLE_KEY = "@MOUSE_TOGGLE_KEY@"
MULTITAP_TIMEOUT = 0.9

# Mouse mode tuning: pixels per key press, growing while a direction is
# held/repeated (presses of the same direction within MOUSE_REPEAT_WINDOW).
MOUSE_BASE_STEP = 10
MOUSE_MAX_STEP = 80
MOUSE_ACCEL = 5
MOUSE_REPEAT_WINDOW = 0.4
# Give the compositor time to pick up the freshly created pointer device.
MOUSE_SETTLE = 0.3

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


def enable_mouse_mode():
    global mouse, mouse_mode, last_direction, direction_streak

    if mouse is None:
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
            return
        time.sleep(MOUSE_SETTLE)

    last_direction = None
    direction_streak = 0
    mouse_mode = True
    logging.info("Mouse mode on")


def disable_mouse_mode():
    global mouse, mouse_mode

    mouse_mode = False

    if mouse is not None:
        mouse.close()
        mouse = None
        logging.info("Mouse mode off")


def toggle_mouse_mode():
    if mouse_mode:
        disable_mouse_mode()
    else:
        enable_mouse_mode()


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
    subprocess.run(
        ["systemctl", "restart", PEGASUS_SERVICE],
        check=False,
        timeout=30,
    )


def handle_command(command):
    if command == MOUSE_TOGGLE_KEY:
        reset_multitap()
        toggle_mouse_mode()
        return

    if mouse_mode:
        if command in MOUSE_DIRECTIONS:
            move_mouse(command)
            return

        if command == "select":
            click_mouse()
            logging.info("Click")
            return

    if command in KEY_MAP:
        reset_multitap()
        tap(KEY_MAP[command])
        logging.info("Key: %s", command)
        return

    if command in DIGITS:
        digit = DIGITS[command]
        type_digit(digit)
        logging.info("Digit: %s", digit)
        return

    if command == "electronic-program-guide":
        return_to_pegasus()
        return

    logging.debug("Ignoring CEC command: %s", command)


def main():
    command = [
        STDBUF,
        "-oL",
        CEC_CTL,
        "-d",
        CEC_DEVICE,
        "--monitor",
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
        for line in process.stdout:
            match = re.search(r"ui-cmd:\s+([a-z0-9-]+)", line)
            if match:
                handle_command(match.group(1))
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