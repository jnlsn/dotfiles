"""Codex setup merges and backups, using isolated directories only."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest

HAS_TOMLKIT = importlib.util.find_spec('tomlkit') is not None
if HAS_TOMLKIT:
    import tomlkit
    spec = importlib.util.spec_from_file_location('codex_setup', Path(__file__).resolve().parents[1] / 'codex/install.py')
    setup = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(setup)


@unittest.skipUnless(HAS_TOMLKIT, 'Install tomlkit to run Codex merge tests')
class CodexTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.target = self.root / 'codex'
        self.target.mkdir()
        self.config = self.target / 'config.toml'
        self.agents = self.target / 'AGENTS.md'

    def install(self, check=False):
        with contextlib.redirect_stdout(io.StringIO()):
            return setup.install(self.target, check=check)

    def test_fresh_install_and_idempotence(self):
        self.install()
        before = {p.name: p.read_bytes() for p in self.target.iterdir()}
        self.install()
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.target.iterdir()})
        self.assertTrue(self.install(check=True))
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.agents.stat().st_mode & 0o777, 0o600)

    def test_preserves_settings_trust_and_comments(self):
        old = '''# Personal model choice
model = "my-model"
approval_policy = "on-request"
[tui]
# Keep animations off
animations = false
status_line = ["git-branch"]
[projects."/workspaces/example"]
trust_level = "trusted"
[hooks.state.example]
trusted_hash = "test-hash"
[mcp_servers.example]
command = "my-server"
[profiles.custom]
model = "another-model"
'''
        self.config.write_text(old)
        self.install()
        new = self.config.read_text()
        parsed_old, parsed_new = tomlkit.parse(old), tomlkit.parse(new)
        del parsed_old['tui']['status_line']
        del parsed_new['tui']['status_line']
        self.assertEqual(parsed_old, parsed_new)
        self.assertIn('# Personal model choice', new)
        self.assertIn('# Keep animations off', new)
        self.assertEqual((self.target / 'config.toml.bak').read_text(), old)

    def test_inline_tui_table(self):
        self.config.write_text('tui = { animations = false }\n')
        self.install()
        data = tomlkit.parse(self.config.read_text())
        self.assertFalse(data['tui']['animations'])
        self.assertIn('context-used', data['tui']['status_line'])

    def test_preserves_instructions_outside_managed_block(self):
        self.agents.write_text('# Existing preferences\nUse project conventions.\n')
        self.install()
        self.agents.write_text(self.agents.read_text() + '\nLocal addition.\n')
        self.install()
        text = self.agents.read_text()
        self.assertTrue(text.startswith('# Existing preferences\nUse project conventions.\n'))
        self.assertTrue(text.endswith('\nLocal addition.\n'))
        self.assertEqual(text.count(setup.BEGIN), 1)

    def test_changed_managed_instructions_are_updated(self):
        self.agents.write_text('before\n' + setup.BEGIN + '\nold preference\n' + setup.END + '\nafter\n')
        self.install()
        text = self.agents.read_text()
        self.assertNotIn('old preference', text)
        self.assertTrue(text.startswith('before\n'))
        self.assertTrue(text.endswith('\nafter\n'))

    def test_invalid_input_does_not_write_either_file(self):
        for invalid in ('not valid toml', 'tui = 42'):
            self.config.write_text(invalid)
            self.agents.write_text('original')
            with self.assertRaises(ValueError):
                self.install()
            self.assertEqual(self.config.read_text(), invalid)
            self.assertEqual(self.agents.read_text(), 'original')
            self.assertEqual(len(list(self.target.iterdir())), 2)
        self.config.write_text('model = "local"\n')
        self.agents.write_text(setup.BEGIN + '\nbroken block')
        with self.assertRaises(ValueError):
            self.install()
        self.assertEqual(self.config.read_text(), 'model = "local"\n')
        self.assertEqual(len(list(self.target.iterdir())), 2)

    def test_backups_never_overwrite_even_dangling_links(self):
        self.config.write_text('model = "local"\n')
        (self.target / 'config.toml.bak').write_text('old backup')
        (self.target / 'config.toml.bak.1').symlink_to(self.root / 'missing')
        self.install()
        self.assertEqual((self.target / 'config.toml.bak').read_text(), 'old backup')
        self.assertTrue((self.target / 'config.toml.bak.1').is_symlink())
        self.assertEqual((self.target / 'config.toml.bak.2').read_text(), 'model = "local"\n')

    def test_symlinked_file_is_localized_without_changing_source(self):
        source = self.root / 'config-source'
        source.write_text('model = "local"\n')
        self.config.symlink_to(source)
        self.install()
        self.assertFalse(self.config.is_symlink())
        self.assertEqual(source.read_text(), 'model = "local"\n')
        self.assertEqual((self.target / 'config.toml.bak').read_text(), source.read_text())

    def test_whole_directory_symlink_rejected(self):
        linked = self.root / 'linked'
        linked.symlink_to(self.target)
        with self.assertRaises(ValueError):
            setup.install(linked)
        self.assertEqual(list(self.target.iterdir()), [])

    def test_check_is_read_only(self):
        self.target.rmdir()
        self.assertFalse(self.install(check=True))
        self.assertFalse(self.target.exists())

    def test_auth_and_state_untouched(self):
        auth = self.target / 'auth.json'
        auth.write_text('test-only-auth')
        state = self.target / 'state.sqlite'
        state.write_bytes(b'test-only-state')
        self.install()
        self.assertEqual(auth.read_text(), 'test-only-auth')
        self.assertEqual(state.read_bytes(), b'test-only-state')
