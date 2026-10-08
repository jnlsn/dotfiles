"""Filesystem regression tests; all data and command mocks live in temp dirs."""
import importlib.util
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
COMMON = REPO / 'lib/common.sh'
spec = importlib.util.spec_from_file_location('prepare_stow', REPO / 'lib/prepare-stow.py')
prepare_stow = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare_stow)


class PersistenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.home = self.root / 'local'
        self.efs = self.root / 'efs'
        self.bin = self.root / 'bin'
        for path in (self.home, self.efs, self.bin):
            path.mkdir()
        # Host-independent stand-ins for Linux realpath/mountpoint. No actual
        # mount, credentials, HOME override, or system installer is used.
        self.command('realpath', '#!/usr/bin/env python3\nimport os,sys\nprint(os.path.realpath(sys.argv[-1]))\n')
        self.command('mountpoint', '#!/bin/sh\nexit "${TEST_MOUNT_STATUS:-0}"\n')
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        EFS_MOUNT_POINT=str(self.efs), EFS_DIR=str(self.efs))

    def command(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def shell(self, code, *args, check=True):
        result = subprocess.run(['bash', '-c', 'set -euo pipefail; source "$1"; shift; ' + code,
                                 'test', str(COMMON), *map(str, args)],
                                env=self.env, text=True, capture_output=True)
        if check:
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        return result

    def link(self, name='credential'):
        return self.shell('validate_efs "$1"; link_to_efs "$2" "$1"', self.home, name)

    def test_missing_mount_leaves_local_file(self):
        src = self.home / 'credential'
        src.write_text('local')
        self.env['TEST_MOUNT_STATUS'] = '1'
        result = self.shell('validate_efs "$1"; link_to_efs credential "$1"', self.home, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(src.read_text(), 'local')
        self.assertFalse(src.is_symlink())
        self.assertEqual(list(self.efs.iterdir()), [])

    def test_unsafe_mount_paths_rejected(self):
        for path in (self.home, self.home / 'nested', self.root, Path('/'), Path('relative')):
            with self.subTest(path=path):
                self.env['EFS_MOUNT_POINT'] = str(path)
                self.assertNotEqual(self.shell('validate_efs "$1"', self.home, check=False).returncode, 0)

    def test_symlink_mount_into_home_rejected(self):
        alias = self.root / 'alias'
        alias.symlink_to(self.home)
        self.env['EFS_MOUNT_POINT'] = str(alias)
        self.assertNotEqual(self.shell('validate_efs "$1"', self.home, check=False).returncode, 0)

    def test_first_migration_preserves_backup_and_is_repeatable(self):
        src = self.home / 'credential'
        src.write_text('local')
        src.chmod(0o600)
        self.link()
        self.assertTrue(src.is_symlink())
        self.assertEqual((self.efs / 'credential').read_text(), 'local')
        self.assertEqual((self.home / 'credential.bak').read_text(), 'local')
        self.link()
        self.assertFalse((self.home / 'credential.bak.1').exists())
        self.assertEqual((self.efs / 'credential').stat().st_mode & 0o777, 0o600)

    def test_existing_destination_preserves_both_versions_and_backup(self):
        (self.home / 'credential').write_text('local')
        (self.home / 'credential.bak').write_text('old backup')
        (self.efs / 'credential').write_text('persistent')
        self.link()
        self.assertEqual((self.home / 'credential').read_text(), 'persistent')
        self.assertEqual((self.home / 'credential.bak').read_text(), 'old backup')
        self.assertEqual((self.home / 'credential.bak.1').read_text(), 'local')

    def test_directory_migration(self):
        (self.home / '.aws').mkdir()
        (self.home / '.aws/config').write_text('sample config')
        self.link('.aws')
        self.assertEqual((self.efs / '.aws/config').read_text(), 'sample config')
        self.assertEqual((self.home / '.aws.bak/config').read_text(), 'sample config')

    def test_dangling_old_symlink_preserved(self):
        (self.home / 'credential').symlink_to(self.root / 'missing')
        self.link()
        self.assertTrue((self.home / 'credential.bak').is_symlink())
        self.assertEqual(os.readlink(self.home / 'credential'), str(self.efs / 'credential'))

    def test_empty_first_use_creates_link_without_fake_credentials(self):
        self.link('.codex/auth.json')
        self.assertTrue((self.home / '.codex/auth.json').is_symlink())
        self.assertFalse((self.efs / '.codex/auth.json').exists())
        self.assertFalse((self.home / '.codex').is_symlink())

    def test_redirected_parent_rejected(self):
        outside = self.root / 'outside'
        outside.mkdir()
        (self.home / '.claude').symlink_to(outside)
        result = self.shell('link_to_efs .claude/credential "$1"', self.home, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    def test_persistent_escape_rejected(self):
        (self.efs / 'credential').symlink_to(self.root / 'outside')
        (self.home / 'credential').write_text('local')
        result = self.shell('link_to_efs credential "$1"', self.home, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.home / 'credential').read_text(), 'local')

    def test_copy_failure_preserves_original(self):
        (self.home / 'credential').write_text('local')
        self.command('cp', '#!/bin/sh\nexit 1\n')
        result = self.shell('link_to_efs credential "$1"', self.home, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.home / 'credential').read_text(), 'local')
        self.assertEqual(list(self.efs.iterdir()), [])

    def test_backup_respects_dangling_backup(self):
        (self.home / 'credential').write_text('local')
        (self.home / 'credential.bak').symlink_to(self.root / 'missing')
        self.shell('backup_path "$1"', self.home / 'credential')
        self.assertTrue((self.home / 'credential.bak').is_symlink())
        self.assertEqual((self.home / 'credential.bak.1').read_text(), 'local')


class JiraAuthTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.tokens = self.root / 'tokens'
        self.tokens.mkdir()
        mock = self.bin / 'acli'
        mock.write_text("""#!/usr/bin/env python3
import json,os,stat,sys
from pathlib import Path
if sys.argv[1:] == ['jira','auth','status']:
    sys.exit(int(os.environ.get('MOCK_AUTH_STATUS','1')))
record = {'args': sys.argv[1:], 'private': stat.S_IMODE(os.fstat(0).st_mode) == 0o600,
          'token_received': sys.stdin.read() == 'test-only-token'}
Path(os.environ['MOCK_RECORD']).write_text(json.dumps(record))
print('test-only-token')  # Must be suppressed even on failure.
sys.exit(int(os.environ.get('MOCK_LOGIN_STATUS','0')))
""")
        mock.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        TMPDIR=str(self.tokens), JIRA_API_TOKEN='test-only-token',
                        JIRA_EMAIL='test@example.com', JIRA_SITE='example.atlassian.net',
                        MOCK_RECORD=str(self.root / 'record'))

    def auth(self):
        result = subprocess.run(['bash', '-c', 'set -euo pipefail; source "$1"; authenticate_jira',
                                 'test', str(COMMON)], env=self.env, text=True, capture_output=True)
        self.assertNotIn('test-only-token', result.stdout + result.stderr)
        self.assertEqual(list(self.tokens.iterdir()), [])
        return result

    def test_success_uses_private_file_and_cleans_up(self):
        import json
        self.assertEqual(self.auth().returncode, 0)
        record = json.loads((self.root / 'record').read_text())
        self.assertTrue(record['private'])
        self.assertTrue(record['token_received'])
        self.assertEqual(record['args'], ['jira', 'auth', 'login', '--site', 'example.atlassian.net',
                                          '--email', 'test@example.com', '--token'])

    def test_failed_login_cleans_up(self):
        self.env['MOCK_LOGIN_STATUS'] = '1'
        self.assertNotEqual(self.auth().returncode, 0)

    def test_email_required_and_noreply_rejected(self):
        for email in ('', '123+test@users.noreply.github.com'):
            self.env['JIRA_EMAIL'] = email
            self.assertNotEqual(self.auth().returncode, 0)
            self.assertFalse((self.root / 'record').exists())

    def test_existing_login_does_not_reauthenticate(self):
        self.env['MOCK_AUTH_STATUS'] = '0'
        self.assertEqual(self.auth().returncode, 0)
        self.assertFalse((self.root / 'record').exists())

    def test_unconfigured_token_skips_login(self):
        self.env['JIRA_API_TOKEN'] = ''
        self.assertEqual(self.auth().returncode, 0)
        self.assertFalse((self.root / 'record').exists())


class StowMigrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.repo = self.root / 'repo'
        self.home = self.root / 'local'
        self.repo.mkdir()
        self.home.mkdir()
        self.source = self.repo / 'claude/.claude'
        self.source.mkdir(parents=True)
        (self.source / 'settings.json').write_text('{}')
        (self.source / 'statusline').mkdir()
        (self.source / 'statusline/full.sh').write_text('#!/bin/bash\n')
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        subprocess.run(['git', '-C', str(self.repo), 'add', '.'], check=True)

    def prepare(self):
        prepare_stow.prepare(self.repo, self.home, ['claude'])

    def test_folded_directory_migrates_runtime_and_keeps_managed_links(self):
        (self.home / '.claude').symlink_to(self.source)
        (self.source / '.credentials.json').write_text('sample credential')
        (self.source / 'skills').mkdir()
        (self.source / 'skills/example').write_text('skill')
        self.prepare()
        self.assertFalse((self.home / '.claude').is_symlink())
        self.assertFalse((self.home / '.claude/statusline').is_symlink())
        self.assertTrue((self.home / '.claude/settings.json').is_symlink())
        self.assertEqual((self.home / '.claude/.credentials.json').read_text(), 'sample credential')
        self.assertFalse((self.source / '.credentials.json').exists())
        self.assertEqual((self.home / '.claude/skills/example').read_text(), 'skill')
        self.assertFalse((self.source / 'skills').exists())
        self.prepare()
        self.assertFalse((self.home / '.claude.bak.1').exists())

    def test_unrelated_directory_symlink_is_not_modified(self):
        outside = self.root / 'outside'
        outside.mkdir()
        (self.home / '.claude').symlink_to(outside)
        with self.assertRaises(RuntimeError):
            self.prepare()
        self.assertEqual((self.home / '.claude').resolve(), outside)
        self.assertEqual(list(outside.iterdir()), [])

    def test_conflicting_files_get_numbered_backups(self):
        target = self.home / '.claude'
        target.mkdir()
        (target / 'settings.json').write_text('local')
        (target / 'settings.json.bak').write_text('old')
        self.prepare()
        self.assertEqual((target / 'settings.json.bak').read_text(), 'old')
        self.assertEqual((target / 'settings.json.bak.1').read_text(), 'local')
        self.assertEqual((self.source / 'settings.json').read_text(), '{}')

    def test_removed_neovim_link_is_backed_up(self):
        (self.home / '.config').mkdir()
        target = self.home / '.config/nvim'
        target.symlink_to(self.repo / 'nvim/.config/nvim')
        self.prepare()
        self.assertFalse(target.is_symlink())
        self.assertTrue((self.home / '.config/nvim.bak').is_symlink())

    def test_unrelated_neovim_config_is_preserved(self):
        target = self.home / '.config/nvim'
        target.mkdir(parents=True)
        (target / 'init.lua').write_text('personal config')
        self.prepare()
        self.assertEqual((target / 'init.lua').read_text(), 'personal config')

    @unittest.skipUnless(shutil.which('stow'), 'GNU Stow is required for integration coverage')
    def test_real_stow_migration_and_repeat_install(self):
        gh = self.repo / 'gh/.config/gh'
        gh.mkdir(parents=True)
        (gh / 'config.yml').write_text('git_protocol: ssh\n')
        subprocess.run(['git', '-C', str(self.repo), 'add', '.'], check=True)
        command = ['stow', '--dir', str(self.repo), '--target', str(self.home)]
        subprocess.run(command + ['claude', 'gh'], check=True, capture_output=True)
        self.assertTrue((self.home / '.claude').is_symlink())
        (self.home / '.claude/.credentials.json').write_text('sample credential')
        (self.home / '.config/gh/hosts.yml').write_text('sample auth')
        for _ in range(2):
            prepare_stow.prepare(self.repo, self.home, ['claude', 'gh'])
            result = subprocess.run(
                ['bash', '-c', 'source "$1"; shift; stow "${STOW_OPTIONS[@]}" "$@"',
                 'test', str(COMMON), *command[1:], '--no-folding', '--restow', 'claude', 'gh'],
                text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((self.home / '.claude').is_symlink())
            self.assertFalse((self.home / '.config').is_symlink())
            self.assertFalse((self.home / '.config/gh').is_symlink())
            self.assertEqual((self.home / '.claude/.credentials.json').read_text(), 'sample credential')
            self.assertEqual((self.home / '.config/gh/hosts.yml').read_text(), 'sample auth')
            self.assertTrue((self.home / '.claude/settings.json').is_symlink())
            self.assertTrue((self.home / '.config/gh/config.yml').is_symlink())
        self.assertFalse((self.source / '.credentials.json').exists())
        self.assertFalse((gh / 'hosts.yml').exists())
        # A stray credential in an old checkout must not become a Stow source.
        (gh / 'hosts.yml').write_text('must not install')
        result = subprocess.run(
            ['bash', '-c', 'source "$1"; shift; stow "${STOW_OPTIONS[@]}" "$@"',
             'test', str(COMMON), *command[1:], '--no-folding', '--restow', 'claude', 'gh'],
            text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / '.config/gh/hosts.yml').read_text(), 'sample auth')
        self.assertFalse((self.home / '.config/gh/hosts.yml').is_symlink())


if __name__ == '__main__':
    unittest.main()
