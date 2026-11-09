#!/usr/bin/env python3
"""Check or explicitly prepare an app version. Never commits, tags, pushes or merges."""
import argparse
from pathlib import Path
import re

VERSION = re.compile(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\+([1-9]\d*)')
LINE = re.compile(r'^(version:\s*)([^\s#]+)', re.M)


def validate(value, previous=None):
    match = VERSION.fullmatch(value)
    if not match:
        raise ValueError('Use MAJOR.MINOR.PATCH+BUILD with a positive build number.')
    parsed = tuple(map(int, match.groups()))
    if previous is not None:
        old = validate(previous)
        if parsed[:3] < old[:3] or parsed[3] <= old[3]:
            raise ValueError('Version cannot decrease; build must increase.')
    return parsed


def current(path):
    match = LINE.search(path.read_text())
    if not match:
        raise ValueError('pubspec.yaml has no version.')
    validate(match[2])
    return match[2]


def prepare(path, value):
    validate(value, current(path))
    text = path.read_text()
    path.write_text(LINE.sub(lambda match: match[1] + value, text, count=1))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['check', 'prepare'])
    parser.add_argument('--version', help='Explicit candidate, including +BUILD; prepare only')
    parser.add_argument('--previous', help='Previous delivered MAJOR.MINOR.PATCH+BUILD; check only')
    parser.add_argument('--pubspec', type=Path, default=Path(__file__).resolve().parents[1] / 'pubspec.yaml')
    args = parser.parse_args()
    try:
        if args.action == 'prepare':
            if not args.version or args.previous is not None:
                parser.error('prepare needs --version and does not accept --previous')
            prepare(args.pubspec, args.version)
        else:
            if args.version is not None:
                parser.error('--version is for prepare')
            validate(current(args.pubspec), args.previous)
        print(current(args.pubspec))
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
