"""Edit before copying to the Pico. These describe the transmitter interface."""

TX_GPIO = 2
INVERT_OUTPUT = False  # False: logical receiver high -> Pico high; idle low.
STATE_MACHINE = 0
SYMBOL_US = 1578
FRAME_PERIOD_US = 28928
