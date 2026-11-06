#!/usr/bin/env python3
"""Print Nextcloud calendar events as JSON for the dashboard."""
import base64
from concurrent.futures import ThreadPoolExecutor
import configparser
from datetime import datetime, time, timedelta
import json
import os
from pathlib import Path
import subprocess
from urllib.error import HTTPError
from urllib.parse import urljoin
from urllib.request import Request, urlopen
from xml.etree import ElementTree

from icalendar import Calendar
import recurring_ical_events

SERVICE = 'quickshell-nextcloud-calendar'
LIMIT = 5
DAV = '{DAV:}'
CALDAV = '{urn:ietf:params:xml:ns:caldav}'
APPLE = '{http://apple.com/ns/ical/}'
SOURCE = '{http://calendarserver.org/ns/}source'
PROPFIND = b'''<d:propfind xmlns:d="DAV:" xmlns:a="http://apple.com/ns/ical/" xmlns:s="http://calendarserver.org/ns/">
<d:prop><d:resourcetype/><a:calendar-color/><s:source/></d:prop></d:propfind>'''


def account():
    config = configparser.ConfigParser(interpolation=None, strict=False)
    home = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
    config.read(home / 'Nextcloud/nextcloud.cfg')
    settings = config['Accounts']
    user = settings['0\\dav_user']
    return settings['0\\url'].rstrip('/'), user, settings.get('0\\webflow_user', user)


def read(url, headers=None, method='GET', body=None):
    request = Request(url, body, method=method, headers={'User-Agent': 'quickshell-calendar', **(headers or {})})
    with urlopen(request, timeout=15) as response:
        return response.read()


def parse_events(ics, color, start, end):
    for event in recurring_ical_events.of(Calendar.from_ical(ics)).between(start, end):
        if event.get('STATUS') != 'CANCELLED':
            moment = event.decoded('DTSTART')
            all_day = not isinstance(moment, datetime)
            if all_day:
                moment = datetime.combine(moment, time())
            elif moment.tzinfo:
                moment = moment.astimezone().replace(tzinfo=None)
            yield moment, all_day, str(event.get('SUMMARY') or 'Untitled'), color


def snapshot(events, now):
    events = sorted(events, key=lambda event: event[0])
    upcoming = [event for event in events if (event[0].date() >= now.date() if event[1] else event[0] >= now)]
    days = {}
    for start, _, _, color in events:
        colors = days.setdefault(start.strftime('%Y-%m-%d'), [])
        if color not in colors:
            colors.append(color)
    return {'days': days,
            'upcoming': [{'when': start.strftime('%a %b %-d' if all_day else '%a %b %-d %-I:%M %p'),
                          'title': title, 'color': color}
                         for start, all_day, title, color in upcoming[:LIMIT]]}


def sources(base, user, auth):
    home = f'{base}/remote.php/dav/calendars/{user}/'
    headers = {**auth, 'Depth': '1', 'Content-Type': 'application/xml'}
    for item in ElementTree.fromstring(read(home, headers, 'PROPFIND', PROPFIND)).iter(DAV + 'response'):
        color = item.findtext(f'.//{APPLE}calendar-color', '')[:7]
        feed = item.findtext(f'.//{SOURCE}/{DAV}href')
        if feed:
            yield feed.replace('webcal://', 'https://', 1), {}, color
        elif item.find(f'.//{DAV}resourcetype/{CALDAV}calendar') is not None:
            yield urljoin(home, item.findtext(DAV + 'href')) + '?export', auth, color


def load(source, start, end):
    url, headers, color = source
    try:
        return list(parse_events(read(url, headers), color, start, end))
    except (OSError, ValueError):
        return []


def fetch(base, user, login, password, now):
    token = base64.b64encode(f'{login}:{password}'.encode()).decode()
    start, end = now - timedelta(days=31), now + timedelta(days=366)
    with ThreadPoolExecutor() as pool:
        results = pool.map(lambda source: load(source, start, end), sources(base, user, {'Authorization': 'Basic ' + token}))
    return [event for events in results for event in events]


def main():
    secret = subprocess.run(['secret-tool', 'lookup', 'service', SERVICE], capture_output=True, text=True).stdout
    if not secret:
        return {'error': 'Add a Nextcloud app password to show events.'}
    now = datetime.now()
    try:
        return snapshot(fetch(*account(), secret.strip(), now), now)
    except HTTPError as error:
        return {'error': f'Nextcloud returned {error.code}.'}
    except (OSError, KeyError, ElementTree.ParseError):
        return {'error': 'Could not reach Nextcloud.'}


if __name__ == '__main__':
    print(json.dumps(main()))
