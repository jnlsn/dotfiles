#!/usr/bin/env python3
"""Merge dotfiles-owned Codex settings without replacing machine-local state."""
import argparse
from collections.abc import MutableMapping
import os
from pathlib import Path
import tempfile

try:
    import tomlkit
except ImportError:
    raise SystemExit('Codex setup needs tomlkit (Linux: apt install python3-tomlkit).')

SOURCE = Path(__file__).resolve().parent
BEGIN = '<!-- BEGIN dotfiles:codex -->'
END = '<!-- END dotfiles:codex -->'


def merge_config(existing, template):
    try:
        doc = tomlkit.parse(existing)
        desired = tomlkit.parse(template)['tui']['status_line']
    except (ValueError, KeyError, TypeError):
        raise ValueError('Invalid Codex TOML; files left unchanged') from None
    if 'tui' not in doc:
        doc['tui'] = tomlkit.table()
    if not isinstance(doc['tui'], MutableMapping):
        raise ValueError('Codex tui must be a TOML table; files left unchanged')
    if doc['tui'].get('status_line') == desired:
        return existing
    doc['tui']['status_line'] = desired
    return tomlkit.dumps(doc)


def merge_instructions(existing, template):
    block = BEGIN + '\n' + template.rstrip() + '\n' + END
    if BEGIN not in existing and END not in existing:
        return existing + ('\n\n' if existing and not existing.endswith('\n') else '\n' if existing else '') + block + '\n'
    if existing.count(BEGIN) != 1 or existing.count(END) != 1:
        raise ValueError('Ambiguous Codex instruction markers; files left unchanged')
    start, end = existing.index(BEGIN), existing.index(END)
    if end < start:
        raise ValueError('Reversed Codex instruction markers; files left unchanged')
    return existing[:start] + block + existing[end + len(END):]


def read_existing(path):
    if path.is_symlink() and not path.exists():
        raise ValueError(f'Dangling link at {path}; repair it before installing')
    if path.exists() and not path.is_file():
        raise ValueError(f'Expected a file at {path}')
    return path.read_text() if path.exists() else ''


def replace_file(path, content):
    # Copy a private, collision-safe snapshot without changing a symlink target.
    if path.exists():
        index = 0
        while True:
            backup = Path(str(path) + '.bak' + (f'.{index}' if index else ''))
            try:
                descriptor = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                break
            except FileExistsError:
                index += 1
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(path.read_bytes())
    descriptor, staged = tempfile.mkstemp(prefix='.dotfiles-', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(staged, path)
    finally:
        if os.path.exists(staged):
            os.unlink(staged)


def install(target, check=False):
    if target.is_symlink():
        raise ValueError('Codex home must be a real local directory; refusing a whole-directory symlink')
    config, agents = target / 'config.toml', target / 'AGENTS.md'
    old_config, old_agents = read_existing(config), read_existing(agents)
    # Validate both inputs before making any changes.
    new_config = merge_config(old_config, (SOURCE / 'config.toml').read_text())
    new_agents = merge_instructions(old_agents, (SOURCE / 'instructions.md').read_text())
    changes = [(config, old_config, new_config), (agents, old_agents, new_agents)]
    pending = [(path, old, new) for path, old, new in changes if old != new or path.is_symlink()]
    override = target / 'AGENTS.override.md'
    if override.exists() and override.read_text().strip():
        print('[warn] AGENTS.override.md takes precedence over the managed AGENTS.md')
    if check:
        for path, _, _ in pending:
            print(f'[warn] Codex setup needs updating: {path.name}')
        return not pending
    if not pending:
        print('[skip] Codex preferences already installed')
        return True
    target.mkdir(parents=True, exist_ok=True, mode=0o700)
    for path, old, new in pending:
        if read_existing(path) != old:
            raise ValueError('Codex configuration changed during installation; rerun to merge it')
        replace_file(path, new)
    print('[ ok ] Codex preferences installed')
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', type=Path, default=Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex'))))
    parser.add_argument('--check', action='store_true', help='Check managed settings without writing')
    args = parser.parse_args()
    try:
        raise SystemExit(0 if install(args.target.absolute(), args.check) else 1)
    except (OSError, ValueError):
        # Existing TOML can contain credentials; never echo its parser diagnostics.
        raise SystemExit('[error] Codex setup failed: check TOML, instruction markers, file access, and directory symlinks. Existing backups are preserved.')
