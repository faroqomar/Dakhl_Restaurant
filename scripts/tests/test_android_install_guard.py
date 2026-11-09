"""Installation safety scenarios use synthetic APKs and a fake tool boundary only."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

SCRIPT = Path(__file__).resolve().parents[1] / 'android_install_guard.py'
spec = importlib.util.spec_from_file_location('android_install_guard', SCRIPT)
guard = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = guard
spec.loader.exec_module(guard)

PACKAGE = 'com.eros.dakhlrestaurant.phase02.verify.fixture1234'
SIGNER = 'a' * 64
NONCE = 'b' * 32
SERIAL = 'emulator-5582'
AVD = 'Dakhl_Phase02_Verify_fixture1234'


class FakeTools:
    def __init__(self):
        self.calls = []
        self.installed = False
        self.retained_uninstalled = False
        self.installed_bytes = b'previous synthetic APK'
        self.signer = SIGNER
        self.installed_signer = SIGNER
        self.report_format = 'legacy'
        self.package = PACKAGE
        self.marker = NONCE
        self.devices = SERIAL + ' device product:sdk model:sdk device:emu\n'
        self.paths = 'package:/data/app/fixture/base.apk\n'
        self.avd = AVD + '\nOK\n'
        self.install_code = 0
        self.install_output = 'Success\n'
        self.users = 'Users:\n\tUserInfo{0:Owner:13} running\n'
        self.version = 1
        self.installed_version = 1
        self.error = None
        self.before_install = None
        self.before_verify = None
        self.query_count = 0
        self.appear_late = False

    def __call__(self, args, timeout):
        self.calls.append(tuple(args))
        out = ''
        code = 0
        if self.error:
            raise self.error
        if args[0] == 'aapt2':
            version = self.installed_version if Path(args[-1]).name.startswith('installed') else self.version
            out = "package: name='%s' versionCode='%s' versionName='fixture'\n" % (self.package, version)
        elif args[0] == 'apksigner':
            path = Path(args[-1])
            if self.before_verify:
                callback, self.before_verify = self.before_verify, None
                callback(path)
            signer = self.installed_signer if path.name.startswith('installed') else self.signer
            if self.report_format == 'v2':
                out = ('Number of signers: 1\nV2 Signer: certificate SHA-256 digest: ' + signer
                       + '\nV2 Signer: public key SHA-256 digest: ' + '9' * 64 + '\n')
            else:
                out = 'Signer #1 certificate SHA-256 digest: ' + signer + '\n'
        elif args[1:] == ['devices', '-l']:
            out = 'List of devices attached\n' + self.devices
        elif args[-3:] == ['emu', 'avd', 'name']:
            out = self.avd
        elif args[-3:] == ['pm', 'list', 'users']:
            out = self.users
        elif 'list' in args and 'packages' in args:
            self.query_count += 1
            if self.appear_late and self.query_count > 1:
                self.installed = True
            present = self.installed or (self.retained_uninstalled and '-u' in args)
            out = 'package:' + PACKAGE + '\n' if present else ''
        elif 'path' in args:
            out = self.paths
        elif 'pull' in args:
            Path(args[-1]).write_bytes(self.installed_bytes)
        elif 'run-as' in args:
            out = self.marker + '\n'
        elif 'install' in args:
            if self.before_install:
                self.before_install(Path(args[-1]))
            code = self.install_code
            if not code:
                self.installed_bytes = Path(args[-1]).read_bytes()
                self.installed = True
            out = self.install_output if not code else 'PRIVATE user account path in tool error'
        else:
            raise AssertionError('Unexpected command: ' + repr(args))
        return subprocess.CompletedProcess(args, code, out, '')


class AndroidInstallGuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.apk = self.root / 'fixture.apk'
        self.apk.write_bytes(b'synthetic prebuilt APK')
        self.sha = hashlib.sha256(self.apk.read_bytes()).hexdigest()
        self.tools = FakeTools()
        self.config = guard.Config(
            apk=self.apk, sha256=self.sha, package=PACKAGE,
            signer_sha256=SIGNER, serial=SERIAL, avd_name=AVD,
            mode='new-isolated-fixture', fixture_id=NONCE,
            source_revision='1' * 40, runtime_revision='2' * 40,
            fixture_only=True, execute=False, adb='adb', aapt2='aapt2',
            apksigner='apksigner', preservation_receipt=None)

    def run_guard(self, **changes):
        return guard.guard_install(guard.replace(self.config, **changes), run=self.tools)

    def refuse(self, code, **changes):
        with self.assertRaises(guard.GuardError) as caught:
            self.run_guard(**changes)
        self.assertEqual(caught.exception.code, code)
        self.assertFalse(any('install' in c for c in self.tools.calls))

    def existing(self):
        self.tools.installed = True
        backup = self.root / 'fixture-backup.bin'
        backup.write_bytes(b'synthetic fixture backup')
        receipt = self.root / 'preservation.json'
        receipt.write_text(json.dumps({
            'schema': 1, 'serial': SERIAL, 'package': PACKAGE,
            'fixture_id': NONCE,
            'installed_apk_sha256': hashlib.sha256(self.tools.installed_bytes).hexdigest(),
            'backup_path': str(backup),
            'backup_sha256': hashlib.sha256(backup.read_bytes()).hexdigest()}))
        self.config = guard.replace(self.config, mode='existing-fixture', preservation_receipt=receipt)
        return receipt, backup

    def test_preflight_verifies_candidate_and_does_not_install(self):
        result = self.run_guard()
        self.assertEqual(result['status'], 'preflight-passed')
        self.assertEqual(result['apk_sha256'], self.sha)
        self.assertEqual(result['source_provenance'], 'caller-attested')
        self.assertFalse(any('install' in c for c in self.tools.calls))

    def test_installs_only_verified_private_snapshot_and_checks_result(self):
        result = self.run_guard(execute=True)
        self.assertEqual(result['status'], 'installed')
        installs = [c for c in self.tools.calls if 'install' in c]
        self.assertEqual(len(installs), 1)
        self.assertEqual(installs[0][1:5], ('-s', SERIAL, 'install', '-r'))
        self.assertNotEqual(Path(installs[0][-1]), self.apk)
        self.assertFalse(Path(installs[0][-1]).exists())
        self.assertEqual(self.tools.installed_bytes, self.apk.read_bytes())

    def test_explicit_emulator_and_fixture_authorization_required(self):
        for changes in ({'serial': ''}, {'serial': 'physical-secret-device'},
                        {'avd_name': ''}, {'fixture_only': False}, {'fixture_id': ''}):
            with self.subTest(changes=changes):
                self.refuse('invalid-authorization', **changes)
                self.assertEqual(self.tools.calls, [])

    def test_normal_app_identity_is_never_mutated(self):
        self.refuse('invalid-authorization', package='com.eros.dakhlrestaurant.phase00')
        self.assertEqual(self.tools.calls, [])

    def test_unexpected_package_refuses_before_install(self):
        self.tools.package = 'other.app'
        self.refuse('package-mismatch')

    def test_unknown_missing_or_multiple_signers_refuse(self):
        for text in ['', 'unknown', SIGNER + '\nSigner #2 certificate SHA-256 digest: ' + SIGNER]:
            with self.subTest(text=text):
                self.tools.signer = text
                self.refuse('ambiguous-signers')

    def test_unexpected_expected_signer_refuses(self):
        self.refuse('signer-mismatch', signer_sha256='c' * 64)

    def test_hash_mismatch_refuses_before_tools(self):
        self.refuse('apk-hash-mismatch', sha256='d' * 64)
        self.assertEqual(self.tools.calls, [])

    def test_apk_symlink_refuses_before_tools(self):
        link = self.root / 'alias.apk'
        link.symlink_to(self.apk)
        self.refuse('unsafe-file', apk=link)
        self.assertEqual(self.tools.calls, [])

    def test_source_path_change_does_not_replace_verified_snapshot(self):
        self.tools.before_verify = lambda _: self.apk.write_bytes(b'changed original source')
        result = self.run_guard(execute=True)
        self.assertEqual(result['status'], 'installed')
        self.assertEqual(hashlib.sha256(self.tools.installed_bytes).hexdigest(), self.sha)

    def test_private_verified_copy_mutation_refuses(self):
        self.tools.before_verify = lambda path: path.write_bytes(b'changed copy')
        self.refuse('apk-changed')

    def test_offline_duplicate_unknown_and_wrong_avd_targets_refuse(self):
        for devices, avd in [(SERIAL + ' offline\n', self.tools.avd),
                             (SERIAL + ' device\n' + SERIAL + ' device\n', self.tools.avd),
                             ('emulator-9998 device\n', self.tools.avd),
                             (self.tools.devices, 'AnotherAVD\nOK\n')]:
            with self.subTest(devices=devices, avd=avd):
                self.tools.devices, self.tools.avd = devices, avd
                self.refuse('target-mismatch')

    def test_new_mode_refuses_installed_or_late_appearing_package(self):
        self.tools.installed = True
        self.refuse('unexpected-installed-package')
        self.tools.installed = False
        self.tools.appear_late = True
        self.tools.query_count = 0
        self.refuse('unexpected-installed-package', execute=True)

    def test_new_mode_refuses_retained_uninstalled_package_data(self):
        self.tools.retained_uninstalled = True
        self.refuse('unexpected-installed-package', execute=True)
        queries = [c for c in self.tools.calls if 'packages' in c]
        self.assertTrue(queries)
        self.assertTrue(all('-u' in c for c in queries))

    def test_postinstall_refuses_dot_segments_before_pulling(self):
        for component in ('.', '..'):
            with self.subTest(component=component):
                self.tools = FakeTools()
                path = '/data/app/' + component + '/base.apk'
                self.tools.before_install = lambda _: setattr(
                    self.tools, 'paths', 'package:' + path + '\n')
                with self.assertRaises(guard.GuardError) as caught:
                    self.run_guard(execute=True)
                self.assertEqual(caught.exception.code, 'postinstall-unverified')
                self.assertFalse(any('pull' in c and path in c for c in self.tools.calls))

    def test_existing_mode_requires_matching_fixture_marker_and_archive(self):
        self.existing()
        result = self.run_guard(execute=True)
        self.assertEqual(result['status'], 'installed')
        self.assertTrue(result['backup_hash_verified'])

    def test_existing_mode_without_receipt_refuses(self):
        self.tools.installed = True
        self.refuse('preservation-required', mode='existing-fixture')

    def test_missing_existing_package_refuses(self):
        self.existing()
        self.tools.installed = False
        self.refuse('missing-installed-package')

    def test_installed_signer_mismatch_refuses_without_uninstall(self):
        self.existing()
        self.tools.installed_signer = 'e' * 64
        self.refuse('installed-signer-mismatch')

    def test_installed_split_or_unknown_path_refuses(self):
        self.existing()
        for paths in ['package:/data/app/f/base.apk\npackage:/data/app/f/split.apk\n',
                      'package:../../../private.apk\n', 'garbage\n']:
            with self.subTest(paths=paths):
                self.tools.paths = paths
                self.refuse('unsupported-installed-apks')

    def test_wrong_fixture_marker_refuses(self):
        self.existing()
        self.tools.marker = 'not-owned'
        self.refuse('fixture-identity-mismatch')

    def test_changed_missing_or_symlink_backup_refuses(self):
        receipt, backup = self.existing()
        backup.write_bytes(b'changed backup')
        self.refuse('backup-mismatch')
        backup.unlink()
        self.refuse('unsafe-file')
        backup.symlink_to(self.apk)
        self.refuse('unsafe-file')

    def test_receipt_identity_or_apk_hash_mismatch_refuses(self):
        receipt, _ = self.existing()
        x = json.loads(receipt.read_text())
        x['installed_apk_sha256'] = 'f' * 64
        receipt.write_text(json.dumps(x))
        self.refuse('preservation-mismatch')
        x['package'] = 'wrong.app'
        receipt.write_text(json.dumps(x))
        self.refuse('preservation-mismatch')

    def test_failed_install_never_calls_uninstall_or_clear(self):
        self.tools.install_code = 1
        with self.assertRaises(guard.GuardError) as caught:
            self.run_guard(execute=True)
        self.assertEqual(caught.exception.code, 'install-failed')
        self.assertEqual(len([c for c in self.tools.calls if 'install' in c]), 1)
        self.assertFalse(any('uninstall' in c or 'clear' in c for c in self.tools.calls))
        self.assertNotIn('PRIVATE', str(caught.exception))

    def test_tool_timeout_or_unknown_output_is_sanitized(self):
        for error in [subprocess.TimeoutExpired(['PRIVATE'], 10), OSError('PRIVATE')]:
            with self.subTest(error=type(error).__name__):
                self.tools.error = error
                with self.assertRaises(guard.GuardError) as caught:
                    self.run_guard()
                self.assertEqual(caught.exception.code, 'tool-failed')
                self.assertNotIn('PRIVATE', str(caught.exception))

    def test_additional_or_unknown_device_users_refuse(self):
        for users in ['Users:\n UserInfo{0:Owner:13} running\n UserInfo{10:Private:10} running\n', '', 'unknown']:
            with self.subTest(users=users):
                self.tools.users = users
                self.refuse('target-users-unknown')

    def test_downgrade_refuses_before_install(self):
        self.existing()
        self.tools.installed_version = 2
        self.refuse('version-downgrade')

    def test_duplicate_receipt_keys_refuse(self):
        receipt, _ = self.existing()
        text = receipt.read_text()
        receipt.write_text(text[:-1] + ', "schema": 1}')
        self.refuse('preservation-mismatch')

    def test_success_exit_without_install_success_is_not_accepted(self):
        for output in ['', 'Failure [INTERNAL_ERROR]', 'PRIVATE unexpected output']:
            with self.subTest(output=output):
                self.tools.install_output = output
                self.tools.installed = False
                with self.assertRaises(guard.GuardError) as caught:
                    self.run_guard(execute=True)
                self.assertEqual(caught.exception.code, 'install-unconfirmed')
                self.assertNotIn('PRIVATE', str(caught.exception))
                self.tools.installed = False

    def test_existing_marker_loss_after_install_is_not_preservation_success(self):
        self.existing()
        self.tools.before_install = lambda _: setattr(self.tools, 'marker', 'lost')
        with self.assertRaises(guard.GuardError) as caught:
            self.run_guard(execute=True)
        self.assertEqual(caught.exception.code, 'postinstall-preservation-unverified')
        self.assertFalse(any('uninstall' in c or 'clear' in c for c in self.tools.calls))

    def test_malformed_or_excessively_nested_receipt_refuses(self):
        receipt, _ = self.existing()
        for data in [b'{bad', b'\xff', b'[' * 1500 + b']' * 1500]:
            with self.subTest(kind=data[:8]):
                receipt.write_bytes(data)
                self.refuse('preservation-mismatch')

    def test_apk_fifo_hardlink_and_oversize_refuse_before_tools(self):
        fifo = self.root / 'input-pipe.apk'
        import os
        os.mkfifo(fifo)
        self.refuse('unsafe-file', apk=fifo)
        linked = self.root / 'linked.apk'
        os.link(self.apk, linked)
        self.refuse('unsafe-file', apk=linked)
        linked.unlink()
        large = self.root / 'oversize.apk'
        with large.open('wb') as output:
            output.truncate(guard.FILE_LIMIT + 1)
        self.refuse('unsafe-file', apk=large)
        self.assertEqual(self.tools.calls, [])

    def test_sdk37_v2_single_signer_report_uses_certificate_digest(self):
        text = ('Verifies\nNumber of signers: 1\n'
                'V2 Signer: certificate DN: CN=Synthetic Fixture\n'
                'V2 Signer: certificate SHA-256 digest: ' + SIGNER + '\n'
                'V2 Signer: public key SHA-256 digest: ' + '9' * 64 + '\n')
        self.assertEqual(guard.parse_signer_report(text), SIGNER)
        self.tools.report_format = 'v2'
        self.assertEqual(self.run_guard(execute=True)['status'], 'installed')

    def test_v2_installed_fixture_uses_same_strict_parser(self):
        self.existing()
        self.tools.report_format = 'v2'
        self.assertEqual(self.run_guard(execute=True)['status'], 'installed')

    def test_v2_requires_one_unambiguous_signer_count(self):
        digest_line = 'V2 Signer: certificate SHA-256 digest: ' + SIGNER + '\n'
        for prefix in ['', 'Number of signers: 2\n',
                       'Number of signers: unknown\n',
                       'Number of signers: 1\nNumber of signers: 1\n']:
            with self.subTest(prefix=prefix), self.assertRaises(guard.GuardError):
                guard.parse_signer_report(prefix + digest_line)

    def test_mixed_duplicate_conflicting_or_unknown_signer_reports_refuse(self):
        good = 'Number of signers: 1\nV2 Signer: certificate SHA-256 digest: ' + SIGNER + '\n'
        for extra in [
                'V2 Signer: certificate SHA-256 digest: ' + SIGNER + '\n',
                'V2 Signer: certificate SHA-256 digest: ' + 'c' * 64 + '\n',
                'Signer #1 certificate SHA-256 digest: ' + SIGNER + '\n',
                'Signer #1 public key SHA-256 digest: ' + '9' * 64 + '\n',
                'V3 Signer: certificate SHA-256 digest: ' + SIGNER + '\n',
                'V3.1 Signer: certificate DN: CN=Fixture\n',
                'Unknown Signer: certificate DN: CN=Fixture\n',
                'Signer certificate lineage: unknown\n',
                'Signing certificate rotation: present\n']:
            with self.subTest(extra=extra), self.assertRaises(guard.GuardError):
                guard.parse_signer_report(good + extra)

    def test_legacy_signer_format_remains_strict(self):
        good = 'Signer #1 certificate SHA-256 digest: ' + SIGNER.upper() + '\n'
        self.assertEqual(guard.parse_signer_report(good), SIGNER)
        self.assertEqual(guard.parse_signer_report('Number of signers: 1\n' + good), SIGNER)
        for extra in ['Number of signers: unknown\n', 'Number of signers: 2\n',
                      'Signer #2 public key SHA-256 digest: ' + SIGNER + '\n',
                      'V2 Signer: certificate DN: CN=Fixture\n',
                      'Unknown Signer: certificate DN: CN=Fixture\n']:
            with self.subTest(extra=extra), self.assertRaises(guard.GuardError):
                guard.parse_signer_report(good + extra)

    def test_case_variant_or_malformed_signer_fields_are_ambiguous(self):
        good = 'Number of signers: 1\nV2 Signer: certificate SHA-256 digest: ' + SIGNER + '\n'
        for extra in ['V3 signer: certificate DN: CN=Fixture\n',
                      'number of signers: 1\n',
                      'V2 Signer: certificate sha-256 digest: ' + SIGNER + '\n']:
            with self.subTest(extra=extra), self.assertRaises(guard.GuardError):
                guard.parse_signer_report(good + extra)

    def test_cli_missing_authorization_outputs_json_without_payload(self):
        out = io.StringIO()
        err = io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            result = guard.main(['--apk', '/PRIVATE/account/path'])
        self.assertEqual(result, 2)
        self.assertEqual(json.loads(out.getvalue())['code'], 'invalid-arguments')
        self.assertNotIn('PRIVATE', out.getvalue() + err.getvalue())


if __name__ == '__main__':
    unittest.main()
