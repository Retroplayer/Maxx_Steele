"""Build with real KickAssembler, then verify the stock 8 KiB ROM byte for byte.

The assembly does not read the reference binary. The reference is used only
after compilation, for an independent comparison.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_JAR = ROOT.parent / '.tools/kickassembler/5.25/KickAss.jar'
EXPECTED_PAYLOAD_SHA256 = 'f232722d4773303b3e85bf3188af936735007207de8ce5ecc739bdd7348ebecd'
EXPECTED_MAPPED_SHA256 = 'd6359ba53a5072ecf2e8703cecda8c63bb9a47c8f39cd07dd047089b2f2c1746'


def build(jar, reference=None, output_dir=None):
    jar = jar.resolve()
    if not jar.is_file():
        raise RuntimeError('KickAss.jar missing: run tools/install_kickassembler.py or supply --jar.')
    output_dir = (output_dir or ROOT / 'asm/build').resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    binary = output_dir / 'main-rom.bin'
    mapped = output_dir / 'main-rom-mapped.bin'
    report_path = output_dir / 'verification.json'
    # An old artifact must never masquerade as a successful current build.
    for path in (binary, mapped, report_path, output_dir / 'main.sym'):
        path.unlink(missing_ok=True)
    command = ['java', '-jar', str(jar), str(ROOT / 'asm/main.asm'),
               '-binfile', '-odir', str(output_dir), '-o', str(binary), '-symbolfile']
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    log = result.stdout + result.stderr
    (output_dir / 'assembler.log').write_text(log)
    # KickAssembler can return exit status 0 despite FAILED layout assertions.
    assertions = re.search(r'Made (\d+) asserts\s*,\s*(\d+) (?:failed|FAILED)', log)
    if result.returncode or 'ERROR IN ASSERTION' in log or not assertions or int(assertions[2]):
        raise RuntimeError('Assembly failed or assertions did not pass. See ' + str(output_dir / 'assembler.log'))
    if not binary.is_file():
        raise RuntimeError('Assembler did not produce the requested output.')
    payload = binary.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    if len(payload) != 8192 or digest != EXPECTED_PAYLOAD_SHA256:
        raise RuntimeError(f'Stock ROM mismatch: {len(payload)} bytes, SHA-256 {digest}.')
    compared_bytes = 0
    reference_kind = None
    if reference:
        original = reference.read_bytes()
        if len(original) == 65536:
            if hashlib.sha256(original).hexdigest() != EXPECTED_MAPPED_SHA256:
                raise RuntimeError('Reference mapped ROM has the wrong hash.')
            original = original[0xE000:]
            reference_kind = '64 KiB mapped input, compared only at E000-FFFF'
        elif len(original) == 8192:
            reference_kind = '8 KiB raw main ROM'
        else:
            raise RuntimeError('Reference must be the original 8 KiB payload or 64 KiB mapped image.')
        if original != payload:
            differences = [i for i, (a, b) in enumerate(zip(original, payload)) if a != b]
            raise RuntimeError('Reference comparison failed at CPU addresses: ' + ', '.join(f'{0xE000+i:04X}' for i in differences[:16]))
        compared_bytes = 8192
    normalized = bytes(0xE000) + payload
    assert hashlib.sha256(normalized).hexdigest() == EXPECTED_MAPPED_SHA256
    mapped.write_bytes(normalized)
    symbols_path = output_dir / 'main.sym'
    if not symbols_path.is_file():
        raise RuntimeError('Assembler did not generate main.sym.')
    symbol_text = symbols_path.read_text()
    symbols = {name: int(value, 16) for name, value in re.findall(r'\.label (\w+)=\$([0-9A-Fa-f]+)', symbol_text)}
    checks = {'ROMStart': 0xE000, 'ResetEntry': 0xE041, 'NMIEntry': 0xE011,
              'IRQEntry': 0xFDC5, 'HardwareVectors': 0xFFFA, 'ROMEnd': 0x10000}
    for name, address in checks.items():
        if symbols.get(name) != address:
            raise RuntimeError(f'Symbol address mismatch for {name}: {symbols.get(name)} != {address}.')
    version = re.search(r'Kick Assembler v([\d.]+)', log)
    report = {
        'assembler': 'KickAssembler', 'assembler_version': version[1] if version else 'unknown',
        'assembler_jar_sha256': hashlib.sha256(jar.read_bytes()).hexdigest(),
        'output_bytes': len(payload), 'payload_sha256': digest,
        'mapped_sha256': hashlib.sha256(normalized).hexdigest(),
        'layout_assertions_passed': int(assertions[1]), 'layout_assertions_failed': 0,
        'reference_kind': reference_kind, 'reference_bytes_compared': compared_bytes,
        'reference_mismatches': 0 if reference else None,
        'fixed_symbol_checks': {name: f'{value:05X}' for name, value in checks.items()},
        'binary_input_used_by_assembler': False,
    }
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--jar', type=Path, default=Path(os.environ.get('KICKASS_JAR', str(DEFAULT_JAR))))
    parser.add_argument('--reference', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        report = build(args.jar, args.reference, args.output)
    except (RuntimeError, OSError) as error:
        parser.exit(1, str(error) + '\n')
    print(f"KickAssembler {report['assembler_version']}: {report['output_bytes']} bytes, "
          f"{report['layout_assertions_passed']} assertions passed; stock ROM SHA-256 matches.")
    if args.reference:
        print('Independent reference comparison: 8,192 bytes, zero differences.')
