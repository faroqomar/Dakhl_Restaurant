#!/usr/bin/env python3
"""Embed the existing qualified-byte ICU development bundle; never build ICU."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ENTRY = 'libicu_collation_pilot.dylib'
BRIDGE = 'f31e81506b3af2d3a48496094f8c9cc98be9cfe2cc0010f6d54658baade81091'
FILES = {ENTRY, 'LICENSE', 'icu-install/lib/libicui18n.78.2.dylib',
         'icu-install/lib/libicuuc.78.2.dylib', 'icu-install/lib/libicudata.78.2.dylib'}
LINKS = {'icu-install/lib/libicui18n.78.dylib': 'libicui18n.78.2.dylib',
         'icu-install/lib/libicuuc.78.dylib': 'libicuuc.78.2.dylib',
         'icu-install/lib/libicudata.78.dylib': 'libicudata.78.2.dylib'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(directory, manifest, resources=None):
    if (manifest.get('formatVersion') != 1 or manifest.get('platform') != 'macos-arm64'
            or manifest.get('entryLibrary') != ENTRY or set(manifest.get('files', {})) != FILES
            or manifest.get('symlinks') != LINKS or manifest['files'][ENTRY]['sha256'] != BRIDGE):
        raise ValueError('ICU development bundle identity mismatch')
    for relative, identity in manifest['files'].items():
        path = (resources if resources is not None and relative == 'LICENSE' else directory) / relative
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to((resources if resources is not None and relative == 'LICENSE' else directory).resolve()):
            raise ValueError('ICU development payload is incomplete')
        if path.stat().st_size != identity['bytes'] or digest(path) != identity['sha256']:
            raise ValueError('ICU development payload digest mismatch')
    for relative, target in LINKS.items():
        path = directory / relative
        if not path.is_symlink() or os.readlink(path) != target:
            raise ValueError('ICU development loader topology mismatch')


def verify_generated_inventory(directory, resources=None, code_only=False, resources_only=False):
    def check(root, files):
        allowed = set(files)
        for name in files:
            allowed.update(str(parent) for parent in Path(name).parents if str(parent) != '.')
        actual = {str(path.relative_to(root)) for path in root.rglob('*')}
        if actual != allowed:
            raise ValueError('Unexpected generated ICU files must be preserved')
    if resources_only:
        check(directory, {'LICENSE', 'manifest.json'})
    elif code_only:
        check(directory, (FILES - {'LICENSE'}) | set(LINKS))
    elif resources is None:
        check(directory, FILES | set(LINKS) | {'manifest.json'})
    else:
        check(directory, (FILES - {'LICENSE'}) | set(LINKS))
        check(resources, {'LICENSE', 'manifest.json'})


def main():
    source = Path(os.environ.get('MADAR_ICU_RUNTIME_DIR', ROOT.parent / 'Madar_Engine/outputs/icu-runtime/macos-arm64'))
    target_root = Path(os.environ['TARGET_BUILD_DIR']) / os.environ['FRAMEWORKS_FOLDER_PATH']
    resources_root = Path(os.environ['TARGET_BUILD_DIR']) / os.environ['UNLOCALIZED_RESOURCES_FOLDER_PATH']
    destination = target_root / 'MadarIcu'
    resources = resources_root / 'MadarIcu'

    def remove_existing(canonical=None):
        if not destination.exists() and not resources.exists():
            return
        if (canonical is not None and destination.exists() and not resources.exists()
                and not (destination / 'manifest.json').exists()):
            # A failed second rename can leave only code. Recover solely when
            # every code byte/link and the exact inventory matches this source.
            verify(destination, canonical, source)
            verify_generated_inventory(destination, code_only=True)
            shutil.rmtree(destination)
            return
        if canonical is not None and resources.exists() and not destination.exists():
            # Interrupted cleanup can leave only resources. Their complete
            # inventory, manifest and license must still match this source.
            manifest_path, license_path = resources / 'manifest.json', resources / 'LICENSE'
            if manifest_path.is_symlink() or license_path.is_symlink():
                raise ValueError('Unexpected partial ICU resources must be preserved')
            old = json.loads(manifest_path.read_text())
            identity = canonical['files']['LICENSE']
            if (old != canonical or not license_path.is_file()
                    or license_path.stat().st_size != identity['bytes']
                    or digest(license_path) != identity['sha256']):
                raise ValueError('Partial ICU resources do not match source')
            verify_generated_inventory(resources, resources_only=True)
            shutil.rmtree(resources)
            return
        # Old generated builds placed non-code beside signed libraries. Verify
        # their complete original identities before removing only that copy.
        old_resources = destination if (destination / 'manifest.json').is_file() else resources
        old = json.loads((old_resources / 'manifest.json').read_text())
        verify(destination, old, None if old_resources == destination else resources)
        verify_generated_inventory(destination, None if old_resources == destination else resources)
        shutil.rmtree(destination)
        if old_resources != destination:
            shutil.rmtree(resources)

    if not (source / 'manifest.json').is_file():
        if os.environ.get('MADAR_REQUIRE_ICU_RUNTIME') == '1':
            raise ValueError('Required ICU development runtime has not been prepared')
        remove_existing()
        print(json.dumps({'event': 'icu_embed', 'level': 'warning', 'code': 'unavailable'}))
        return
    manifest = json.loads((source / 'manifest.json').read_text())
    verify(source, manifest)
    if destination.exists() and (resources / 'manifest.json').is_file():
        try:
            verify(destination, manifest, resources)
            verify_generated_inventory(destination, resources)
            if (resources / 'manifest.json').read_bytes() == (source / 'manifest.json').read_bytes():
                print(json.dumps({'event': 'icu_embed', 'level': 'info', 'code': 'reused'}))
                return
        except (ValueError, OSError):
            pass
    target_root.mkdir(parents=True, exist_ok=True)
    resources_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.madar-icu-', dir=target_root) as temporary:
        staged = Path(temporary) / 'MadarIcu'
        staged_resources = Path(temporary) / 'resources'
        staged.mkdir()
        staged_resources.mkdir()
        for relative in FILES | {'manifest.json'}:
            parent = staged_resources if relative in {'LICENSE', 'manifest.json'} else staged
            target = parent / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / relative, target)
        for relative, target in LINKS.items():
            (staged / relative).symlink_to(target)
        verify(staged, manifest, staged_resources)
        remove_existing(manifest)
        staged.replace(destination)
        staged_resources.replace(resources)
    print(json.dumps({'event': 'icu_embed', 'level': 'info', 'code': 'embedded', 'bytes': manifest['runtimeBytes']}))


if __name__ == '__main__':
    try:
        main()
    except (KeyError, ValueError, OSError) as error:
        print(f'ICU bundle embedding failed: {type(error).__name__}', file=sys.stderr)
        raise SystemExit(1)
