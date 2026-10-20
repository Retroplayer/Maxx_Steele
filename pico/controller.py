"""Nonblocking USB-command/held-key scheduler, without hardware dependencies."""

from protocol import KEY_NAMES, key_id

LEASE_MS = 2000
MAX_PENDING = 32


class Controller:
    def __init__(self, now=0, ticks_diff=None):
        self.diff = ticks_diff or (lambda a, b: a - b)
        self.last_contact = now
        self.active = []  # (key ID, start time, optional tap duration)
        self.pending = []  # (key ID, release)
        self.round_robin = 0

    def _room(self, count):
        if len(self.pending) + count > MAX_PENDING:
            raise ValueError("Command queue full; wait before sending more keys")

    def release(self, identifier):
        if any(k == identifier for k, _, _ in self.active):
            self._room(1)
            self.active = [entry for entry in self.active if entry[0] != identifier]
            self.pending.append((identifier, True))

    def stop(self):
        # A previously queued hardware frame can finish; software queue is replaced.
        held = [k for k, _, _ in self.active]
        self.active = []
        self.pending = [(25, False)] + [(k, True) for k in held]

    def advance(self, now):
        if self.active and self.diff(now, self.last_contact) >= LEASE_MS:
            self.stop()
            return
        for identifier, start, duration in tuple(self.active):
            if duration is not None and self.diff(now, start) >= duration:
                # At queue saturation, stop is still available and bounds held time.
                if len(self.pending) >= MAX_PENDING:
                    self.stop()
                    return
                self.release(identifier)

    def next_frame(self):
        if self.pending:
            return self.pending.pop(0)
        if self.active:
            self.round_robin %= len(self.active)
            key = self.active[self.round_robin][0]
            self.round_robin = (self.round_robin + 1) % len(self.active)
            return key, False
        return None

    def command(self, text, now):
        parts = text.upper().split()
        if not parts:
            raise ValueError("Empty command")
        op = parts[0]
        if op in ("PING", "STATUS", "KEYS", "STOP"):
            if len(parts) != 1:
                raise ValueError(op + " takes no arguments")
            if op == "STOP":
                self.stop()
            result = {"ok": True, "command": op}
            if op == "KEYS":
                result["keys"] = KEY_NAMES
            if op == "STATUS":
                result.update({"active": [KEY_NAMES[k - 1] for k, _, _ in self.active],
                               "pending": len(self.pending), "lease_ms": LEASE_MS})
        elif op in ("DOWN", "UP", "TAP"):
            if len(parts) != 2 and not (op == "TAP" and len(parts) == 3):
                raise ValueError("Use " + op + " KEY" + (" [milliseconds]" if op == "TAP" else ""))
            identifier = key_id(parts[1])
            duration = int(parts[2]) if len(parts) == 3 else 100
            if op == "TAP" and not 60 <= duration <= 60000:
                raise ValueError("Tap duration must be 60..60000 ms")
            if identifier == 25:
                if op != "UP":
                    self.stop()
            elif op == "UP":
                self.release(identifier)
            elif any(k == identifier for k, _, _ in self.active):
                raise ValueError("Key already held; use UP first")
            else:
                if len(self.active) >= 2:
                    raise ValueError("At most two keys may be held")
                self._room(1)
                self.active.append((identifier, now, duration if op == "TAP" else None))
                self.pending.append((identifier, False))
            result = {"ok": True, "command": op, "key": KEY_NAMES[identifier - 1],
                      "queued": True}
        else:
            raise ValueError("Commands: TAP, DOWN, UP, STOP, PING, STATUS, KEYS")
        self.last_contact = now
        return result
