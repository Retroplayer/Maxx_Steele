"""Check the actual CUPL Boolean equations against the cartridge specification.

This verifies Boolean behavior, not WinCUPL syntax/library fitting or timing.
"""
import itertools
import re
from pathlib import Path


def parse_expression(expression):
    tokens = re.findall(r"[A-Za-z_][A-Za-z_0-9]*|[!&#()]", expression)
    assert "".join(tokens) == re.sub(r"\s+", "", expression)
    position = 0

    def atom():
        nonlocal position
        token = tokens[position]
        position += 1
        if token == "!":
            return ("not", atom())
        if token == "(":
            value = disjunction()
            assert tokens[position] == ")"
            position += 1
            return value
        assert re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", token)
        return ("name", token)

    def conjunction():
        nonlocal position
        value = atom()
        while position < len(tokens) and tokens[position] == "&":
            position += 1
            value = ("and", value, atom())
        return value

    def disjunction():
        nonlocal position
        value = conjunction()
        while position < len(tokens) and tokens[position] == "#":
            position += 1
            value = ("or", value, conjunction())
        return value

    tree = disjunction()
    assert position == len(tokens)
    return tree


def verify(path):
    source = re.sub(r"/\*.*?\*/", "", path.read_text(), flags=re.S)
    pins = {name: int(pin) for pin, name in re.findall(
        r"\bPIN\s+(\d+)\s*=\s*(\w+)\s*;", source, re.I)}
    assert len(pins) == len(set(pins.values())) == 17
    assert not ({12, 24} & set(pins.values()))
    # Restrict extraction to complete equation statements, excluding PIN/header.
    equations = {}
    for statement in source.split(";"):
        match = re.fullmatch(r"\s*(\w+)\s*=\s*(.*?)\s*", statement, re.S)
        if match:
            assert match[1] not in equations
            equations[match[1]] = parse_expression(match[2])
    outputs = {name for name, pin in pins.items() if 14 <= pin <= 23}
    assert set(equations) == outputs and len(outputs) == 10
    count = 0
    for nibble, rd_n, wr_n, enable in itertools.product(range(16), (0, 1), (0, 1), (0, 1)):
        values = {f"A{bit}": bool(nibble & (1 << (bit-12))) for bit in range(12, 16)}
        values.update(RD_N=bool(rd_n), WR_N=bool(wr_n), ENABLE=bool(enable))
        pending = set()

        def resolve(name):
            if name not in values:
                assert name not in pending, "Combinational loop"
                pending.add(name)
                values[name] = evaluate(equations[name])
                pending.remove(name)
            return values[name]

        def evaluate(node):
            if node[0] == "name":
                return resolve(node[1])
            if node[0] == "not":
                return not evaluate(node[1])
            left, right = evaluate(node[1]), evaluate(node[2])
            return left and right if node[0] == "and" else left or right

        actual = {name: resolve(name) for name in outputs}
        ram = bool(enable and 2 <= nibble <= 9)
        rom = bool(enable and 10 <= nibble <= 11)
        io = bool(enable and 12 <= nibble <= 13)
        read = not rd_n and bool(wr_n)
        write = bool(rd_n) and not wr_n
        expected = dict(RAM_CS_N=not ram, ROM_CS_N=not rom, IO_CS_N=not io,
                        RAM_OE_N=not (ram and read), RAM_WE_N=not (ram and write),
                        ROM_OE_N=not (rom and read), IO_RD_N=not (io and read),
                        IO_WR_N=not (io and write), RW=not write,
                        BUS_ACTIVE_N=not ((ram or rom or io) and (read or write)))
        assert actual == expected, (nibble, rd_n, wr_n, enable, actual, expected)
        assert sum(not actual[key] for key in ("RAM_CS_N", "ROM_CS_N", "IO_CS_N")) <= 1
        assert actual["RAM_OE_N"] or actual["RAM_WE_N"]
        count += 1
    return count


if __name__ == "__main__":
    source = Path(__file__).resolve().parents[1] / "hardware/decoder/maxx_decoder.pld"
    print(f"Passed {verify(source)} exhaustive decoder combinations from {source.name}.")
