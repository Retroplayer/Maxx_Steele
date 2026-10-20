"""Install the pinned KickAssembler release outside the repository checkout."""
import argparse
import hashlib
import urllib.request
from pathlib import Path

URL = 'https://github.com/c64lib/asm-ka/releases/download/5.25/KickAss.jar'
SHA256 = '9592a39336e73a1db8b4a7749256d62d29b113b1c7f0f6c86ea43870ebd9ae1f'
DEFAULT = Path(__file__).resolve().parents[2] / '.tools/kickassembler/5.25/KickAss.jar'


def install(target):
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == SHA256:
        return 'Existing jar checksum verified'
    with urllib.request.urlopen(URL, timeout=30) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise RuntimeError('Downloaded jar checksum mismatch; file not installed.')
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix('.download')
    temporary.write_bytes(data)
    temporary.replace(target)
    return 'Pinned jar downloaded and checksum verified'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT)
    args = parser.parse_args()
    print(install(args.output) + ': ' + str(args.output))
