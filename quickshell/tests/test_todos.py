#!/usr/bin/env python3
"""Test TODO edits against temporary files, never the real vault."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/obsidian_todos.py'


class TodoTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.note = self.base / 'Vault with spaces/TODO.md'
        self.note.parent.mkdir()
        self.note.write_text('# TODO\n\nKeep **this prose**.\n\n- [ ] Original\n')
        self.env = dict(os.environ, XDG_STATE_HOME=str(self.base / 'state'))

    def command(self, *args):
        result = subprocess.run([sys.executable, str(SCRIPT), '--file', str(self.note), *args], capture_output=True, text=True, env=self.env, timeout=5)
        return json.loads(result.stdout)

    def test_status_does_not_create_a_daily_note_or_state(self):
        original = self.note.read_bytes()
        self.assertEqual(self.command('status')['openCount'], 1)
        self.assertEqual(self.note.read_bytes(), original)
        self.assertEqual(list(self.note.parent.iterdir()), [self.note])
        self.assertFalse((self.base / 'state').exists())

    def test_add_toggle_undo_preserve_text_and_permissions(self):
        original = self.note.read_text()
        self.note.chmod(0o640)
        text = 'Read "chapter 2" & review λ'
        status = self.command('add', '--text', text)
        todo = status['todos'][-1]
        self.assertEqual(todo['text'], text)
        after_add = self.note.read_text()
        self.assertTrue(after_add.startswith(original))
        result = self.command('toggle', '--line', str(todo['line']), '--expect-text', text, '--checked', 'false')
        self.assertEqual(result['doneCount'], 1)
        self.assertEqual(self.note.stat().st_mode & 0o777, 0o640)
        self.command('undo')
        self.assertEqual(self.note.read_text(), after_add)

    def test_stale_toggle_and_undo_preserve_external_edits(self):
        todo = self.command('status')['todos'][0]
        self.note.write_text('- [ ] Changed in Obsidian\n')
        result = self.command('toggle', '--line', str(todo['line']), '--expect-text', todo['text'], '--checked', 'false')
        self.assertEqual(result['state'], 'error')
        self.command('add', '--text', 'Local addition')
        self.note.write_text(self.note.read_text() + 'New external content\n')
        latest = self.note.read_text()
        self.assertEqual(self.command('undo')['state'], 'error')
        self.assertEqual(self.note.read_text(), latest)

    def test_ignore_fenced_examples_and_guard_checkbox_state(self):
        self.note.write_text('```md\n- [ ] Example\n```\n- [x] Parent\n    - [ ] Child\n')
        status = self.command('status')
        self.assertEqual(len(status['todos']), 2)
        self.assertEqual(status['todos'][1]['depth'], 1)
        result = self.command('toggle', '--line', '4', '--expect-text', 'Parent', '--checked', 'false')
        self.assertEqual(result['state'], 'error')

    def test_open_targets_todo_file(self):
        binary = self.base / 'bin'
        binary.mkdir()
        opener = binary / 'xdg-open'
        opener.write_text('#!/bin/sh\nprintf "%s" "$1" > "$TODO_TEST_URI"\n')
        opener.chmod(0o755)
        log = self.base / 'opened-uri'
        self.env.update(PATH=str(binary) + ':' + os.environ['PATH'], TODO_TEST_URI=str(log))
        self.assertEqual(self.command('open')['state'], 'ok')
        from urllib.parse import unquote
        self.assertEqual(unquote(log.read_text()), 'obsidian://open?path=' + str(self.note))


if __name__ == '__main__':
    unittest.main()
