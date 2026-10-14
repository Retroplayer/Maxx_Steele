"""ROM/capture-derived remote encoding; compatible with MicroPython and CPython."""

SYMBOL_US = 1578
FRAME_PERIOD_US = 28928
FRAME_SYMBOLS = 11
GAP_US = FRAME_PERIOD_US - FRAME_SYMBOLS * SYMBOL_US

KEY_NAMES = (
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "LAMP", "HOME", "WAIT", "OCTAVE", "CLEAR", "ENTER", "SONG",
    "CLOCK", "SPEECH", "MOTION", "GAME", "PROGRAM", "LEARN",
    "EXECUTE", "POWER",
)
ALIASES = {
    "LEFT": "0", "FORWARD": "1", "REVERSE": "2", "RIGHT": "3",
    "WRIST_UP": "4", "WRIST_DOWN": "5", "ARMS_UP": "6",
    "ARMS_DOWN": "7", "CLAW_ROTATE": "8", "CLAW": "9",
    "NOTE_REST": "WAIT", "SHIFT_OCTAVE": "OCTAVE", "NOTES": "SONG",
    "STATUS": "CLOCK", "BACK_STEP": "MOTION", "POWER_STOP": "POWER",
}


def key_id(name):
    name = name.upper()
    name = ALIASES.get(name, name)
    try:
        return KEY_NAMES.index(name) + 1
    except ValueError:
        raise ValueError("Unknown key: " + name)


def encode(identifier, release=False):
    if not 1 <= identifier <= 25:
        raise ValueError("Key ID must be 1..25")
    data = identifier | (0x20 if release else 0)
    count = 0
    value = data
    while value:
        count += value & 1
        value >>= 1
    return data | ((count & 3) << 6)


def symbols(code):
    bits = [(code >> shift) & 1 for shift in range(7, -1, -1)]
    return [1] + bits[:3] + [1 - bits[2]] + bits[3:6] + [1 - bits[5]] + bits[6:]


def pio_word(identifier, release=False, inverted=False,
             symbol_us=SYMBOL_US, period_us=FRAME_PERIOD_US):
    """11 output symbols, physical idle bit, and a 20-bit idle-loop count."""
    gap = period_us - FRAME_SYMBOLS * symbol_us
    if symbol_us < 4 or not 5 <= gap < (1 << 20) + 5:
        raise ValueError("Timing outside PIO counter range")
    word = 0
    for bit in symbols(encode(identifier, release)):
        word = (word << 1) | (bit ^ bool(inverted))
    return (word << 21) | (int(bool(inverted)) << 20) | (gap - 5)
