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

ICS = '''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
DTSTART;VALUE=DATE:20261110\r
SUMMARY:Exam\\, part
  two\r
BEGIN:VALARM\r
SUMMARY:Alarm\r
END:VALARM\r
END:VEVENT\r
BEGIN:VEVENT\r
DTSTART:20261108T150000\r
SUMMARY:Lunch\r
END:VEVENT\r
BEGIN:VEVENT\r
DTSTART:20261109T150000\r
STATUS:CANCELLED\r
SUMMARY:Gone\r
END:VEVENT\r
BEGIN:VEVENT\r
DTSTART:20261101T150000\r
END:VEVENT\r
END:VCALENDAR\r
'''


class CalendarTests(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(list(calendar.parse_events(ICS, '#123456')), [
            (datetime(2026, 11, 10), True, 'Exam, part two', '#123456'),
            (datetime(2026, 11, 8, 15), False, 'Lunch', '#123456'),
            (datetime(2026, 11, 1, 15), False, 'Untitled', '#123456'),
        ])

    def test_utc_converts_to_local(self):
        moment, all_day = calendar.parse_start('20261108T150000Z')
        self.assertFalse(all_day)
        self.assertIsNone(moment.tzinfo)

    def test_snapshot(self):
        events = [*calendar.parse_events(ICS, '#123456'), (datetime(2026, 11, 8, 16), False, 'Gym', '#abcdef')]
        result = calendar.snapshot(events, datetime(2026, 11, 8, 12))
        self.assertEqual(result['days'], {'2026-11-01': ['#123456'], '2026-11-08': ['#123456', '#abcdef'],
                                          '2026-11-10': ['#123456']})
        self.assertEqual(result['upcoming'], [
            {'when': 'Sun Nov 8 3:00 PM', 'title': 'Lunch'},
            {'when': 'Sun Nov 8 4:00 PM', 'title': 'Gym'},
            {'when': 'Tue Nov 10', 'title': 'Exam, part two'},
        ])


if __name__ == '__main__':
    unittest.main()
