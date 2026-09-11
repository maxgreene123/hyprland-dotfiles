#!/usr/bin/env python3
"""Read and update checkboxes in an existing Obsidian TODO file."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile
from urllib.parse import quote

CHECKBOX = re.compile(r'^([ \t]*)(?:[-*+]|\d+[.)])\s+\[([ xX])\](.*)$')


def tasks(content):
    result, fence = [], None
    for number, line in enumerate(content.splitlines(), 1):
        marker = re.match(r'^\s*(`{3,}|~{3,})', line)
        if marker:
            run = marker.group(1)
            if fence is None:
                fence = run
            elif run[0] == fence[0] and len(run) >= len(fence):
                fence = None
            continue
        match = CHECKBOX.match(line) if fence is None else None
        if match:
            result.append({'line': number, 'checked': match[2].lower() == 'x',
                           'text': match[3].strip(), 'depth': len(match[1].expandtabs(4)) // 4})
    return result


def snapshot(path):
    entries = tasks(path.read_text())
    done = sum(item['checked'] for item in entries)
    return {'state': 'ok', 'path': str(path), 'exists': True, 'todos': entries,
            'doneCount': done, 'openCount': len(entries) - done}


def write_atomic(path, content):
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    descriptor, temporary = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def update(path, args, state):
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    key = hashlib.sha256(str(path).encode()).hexdigest()
    backup = state / (key + '.json')
    with (state / (key + '.lock')).open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        before = path.read_text()
        if args.action == 'undo':
            if not backup.exists():
                raise ValueError('No TODO edit to undo.')
            previous = json.loads(backup.read_text())
            if before != previous['after']:
                raise ValueError('TODO.md changed in Obsidian; undo would overwrite newer edits.')
            after = previous['before']
        elif args.action == 'add':
            text = (args.text or '').strip()
            if not text or '\n' in text or '\r' in text:
                raise ValueError('Enter a task on one line.')
            after = before + ('' if not before or before.endswith('\n') else '\n') + '- [ ] ' + text + '\n'
        else:
            task = next((task for task in tasks(before) if task['line'] == args.line), None)
            if not task or task['text'] != args.expect_text or task['checked'] != args.checked:
                raise ValueError('This task changed in Obsidian. Refresh before toggling it.')
            lines = before.splitlines(keepends=True)
            match = CHECKBOX.match(lines[args.line - 1])
            offset = match.start(2)
            line = lines[args.line - 1]
            lines[args.line - 1] = line[:offset] + (' ' if task['checked'] else 'x') + line[offset + 1:]
            after = ''.join(lines)
        if path.read_text() != before:
            raise ValueError('TODO.md changed while saving. Retry after it refreshes.')
        if args.action != 'undo':
            write_atomic(backup, json.dumps({'before': before, 'after': after}))
        write_atomic(path, after)
        if args.action == 'undo':
            backup.unlink()
    return snapshot(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--file', type=Path, required=True)
    parser.add_argument('action', choices=['status', 'add', 'toggle', 'undo', 'open'])
    parser.add_argument('--text')
    parser.add_argument('--line', type=int)
    parser.add_argument('--expect-text')
    parser.add_argument('--checked', choices=['true', 'false'])
    args = parser.parse_args()
    args.checked = args.checked == 'true'
    try:
        path = args.file.expanduser().resolve(strict=True)
        if not path.is_file():
            raise ValueError('Choose an existing TODO.md file.')
        if args.action == 'open':
            subprocess.run(['xdg-open', 'obsidian://open?path=' + quote(str(path), safe='')], check=True, stdout=subprocess.DEVNULL)
            result = snapshot(path)
        elif args.action == 'status':
            result = snapshot(path)
        else:
            state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'maxshell/todos'
            result = update(path, args, state)
        print(json.dumps(result))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(json.dumps({'state': 'error', 'error': str(error)}))
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
