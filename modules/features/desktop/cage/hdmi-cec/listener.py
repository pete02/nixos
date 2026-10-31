
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
MULTITAP_TIMEOUT = 0.9

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

KEY_MAP = {
    "select": e.KEY_ENTER,
    "up": e.KEY_UP,
    "right": e.KEY_RIGHT,
    "down": e.KEY_DOWN,
    "left": e.KEY_LEFT,
    "back": e.KEY_ESC,
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


def return_to_pegasus():
    reset_multitap()
    logging.info("Returning to Pegasus by restarting %s", PEGASUS_SERVICE)
    subprocess.run(
        ["systemctl", "restart", PEGASUS_SERVICE],
        check=False,
        timeout=30,
    )


def handle_command(command):
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
