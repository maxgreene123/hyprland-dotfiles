#!/usr/bin/env python3
"""Test calendar parsing without contacting Nextcloud."""
from datetime import datetime
import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/nextcloud_calendar.py'
spec = importlib.util.spec_from_file_location('nextcloud_calendar', SCRIPT)
calendar = importlib.util.module_from_spec(spec)
spec.loader.exec_module(calendar)

ICS = b'''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:test\r
BEGIN:VEVENT\r
UID:all-day\r
DTSTART;VALUE=DATE:20261110\r
SUMMARY:Exam\\, part\r
  two\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:weekly\r
DTSTART:20261102T180000\r
RRULE:FREQ=WEEKLY;COUNT=3\r
EXDATE:20261109T180000\r
SUMMARY:Meeting\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:cancelled\r
DTSTART:20261109T150000\r
STATUS:CANCELLED\r
SUMMARY:Gone\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:untitled\r
DTSTART:20261101T150000Z\r
END:VEVENT\r
END:VCALENDAR\r
'''
WINDOW = datetime(2026, 11, 1), datetime(2026, 12, 1)


class CalendarTests(unittest.TestCase):
    def events(self):
        return sorted(calendar.parse_events(ICS, '#123456', *WINDOW), key=lambda event: event[0])

    def test_parse(self):
        events = self.events()
        self.assertEqual([event[2] for event in events], ['Untitled', 'Meeting', 'Exam, part two', 'Meeting'])
        self.assertEqual(events[1][:2], (datetime(2026, 11, 2, 18), False))
        self.assertEqual(events[2][:2], (datetime(2026, 11, 10), True))
        self.assertEqual(events[3][:2], (datetime(2026, 11, 16, 18), False))

    def test_timezone_becomes_local(self):
        self.assertIsNone(self.events()[0][0].tzinfo)

    def test_snapshot(self):
        events = [*self.events(), (datetime(2026, 11, 2, 19), False, 'Gym', '#abcdef')]
        result = calendar.snapshot(events, datetime(2026, 11, 2, 12))
        self.assertEqual(result['days']['2026-11-02'], ['#123456', '#abcdef'])
        self.assertEqual(result['upcoming'][:3], [
            {'when': 'Mon Nov 2 6:00 PM', 'title': 'Meeting', 'color': '#123456'},
            {'when': 'Mon Nov 2 7:00 PM', 'title': 'Gym', 'color': '#abcdef'},
            {'when': 'Tue Nov 10', 'title': 'Exam, part two', 'color': '#123456'},
        ])


if __name__ == '__main__':
    unittest.main()
