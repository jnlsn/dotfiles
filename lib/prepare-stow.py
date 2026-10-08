#!/usr/bin/env python3
"""Unfold repo-owned directories and preserve Stow conflicts before linking."""
import os
from pathlib import Path
import shutil
import subprocess
import sys


def exists(path):
    return path.exists() or path.is_symlink()


def backup(path):
    candidate = Path(str(path) + '.bak')
    number = 0
    while exists(candidate):
        number += 1
        candidate = Path(str(path) + f'.bak.{number}')
    path.rename(candidate)
    print(f'[info] Preserved {path} as {candidate}')


def prepare(repo, home, packages):
    tracked = subprocess.check_output(['git', '-C', str(repo), 'ls-files', '-z']).decode().split('\0')
    sources = {repo / name for name in tracked if name and name.split('/')[0] in packages and (repo / name).is_file()}
    source_dirs = {parent for src in sources for parent in src.parents if parent != repo and repo in parent.parents}
    roots = [repo / package for package in packages]

    def owned(path):
        return any(path == root or root in path.parents for root in roots)

    def directory(target):
        if target == home:
            return
        directory(target.parent)
        if target.is_symlink():
            source = target.resolve()
            if not source.is_dir() or not owned(source):
                raise RuntimeError(f'Refusing unrelated directory symlink: {target}')
            # Keep a recovery link until migration completes. A rerun can safely
            # finish any remaining leaf links after interruption.
            backup(target)
            target.mkdir()
            for child in source.iterdir():
                dest = target / child.name
                if child in sources or child in source_dirs:
                    dest.symlink_to(os.path.relpath(child, dest.parent))
                else:
                    # Application-created files belong at HOME, not in Git.
                    if child.is_symlink():
                        link = os.readlink(child)
                        if not os.path.isabs(link):
                            link = str(child.parent / link)
                        dest.symlink_to(link)
                        child.unlink()
                    else:
                        shutil.move(str(child), str(dest))
        elif exists(target) and not target.is_dir():
            backup(target)
            target.mkdir()
        else:
            target.mkdir(exist_ok=True)

    for source in sorted(sources):
        relative = source.relative_to(repo).parts[1:]
        target = home.joinpath(*relative)
        directory(target.parent)
        if exists(target):
            if target.is_symlink() and target.resolve() == source.resolve():
                # Stow recognizes relative links only. Normalize older manual
                # absolute links without moving their configuration contents.
                if os.path.isabs(os.readlink(target)):
                    target.unlink()
                    target.symlink_to(os.path.relpath(source, target.parent))
                continue
            backup(target)

    # Retire only links into the removed package, including dangling links.
    old_root = repo / 'nvim'
    old_config = home / '.config/nvim'
    if old_config.is_symlink():
        resolved = old_config.resolve()
        if resolved == old_root or old_root in resolved.parents:
            backup(old_config)
    elif old_config.is_dir():
        for current, dirs, files in os.walk(old_config, followlinks=False):
            for name in dirs + files:
                path = Path(current) / name
                if path.is_symlink() and old_root in path.resolve().parents:
                    backup(path)


if __name__ == '__main__':
    try:
        prepare(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve(), sys.argv[3:])
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(f'[error] {error}')
