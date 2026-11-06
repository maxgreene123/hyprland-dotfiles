#!/usr/bin/env python3
"""Print Nextcloud calendar events as JSON for the dashboard."""
import base64
import configparser
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.error import HTTPError
from urllib.parse import urljoin
from urllib.request import Request, urlopen
from xml.etree import ElementTree

SERVICE = 'quickshell-nextcloud-calendar'
LIMIT = 5
DAV = '{DAV:}'
CALDAV = '{urn:ietf:params:xml:ns:caldav}'
APPLE = '{http://apple.com/ns/ical/}'
PROPFIND = '''<d:propfind xmlns:d="DAV:" xmlns:a="http://apple.com/ns/ical/">
<d:prop><d:resourcetype/><a:calendar-color/></d:prop></d:propfind>'''
QUERY = '''<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
<d:prop><c:calendar-data><c:expand start="{start}" end="{end}"/></c:calendar-data></d:prop>
<c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT">
<c:time-range start="{start}" end="{end}"/>
</c:comp-filter></c:comp-filter></c:filter></c:calendar-query>'''


def account():
    config = configparser.ConfigParser(interpolation=None, strict=False)
    home = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
    config.read(home / 'Nextcloud/nextcloud.cfg')
    settings = config['Accounts']
    user = settings['0\\dav_user']
    return settings['0\\url'].rstrip('/'), user, settings.get('0\\webflow_user', user)


def parse_start(value):
    if len(value) == 8:
        return datetime.strptime(value, '%Y%m%d'), True
    moment = datetime.strptime(value[:15], '%Y%m%dT%H%M%S')
    if value.endswith('Z'):
        moment = moment.replace(tzinfo=timezone.utc).astimezone().replace(tzinfo=None)
    return moment, False


def parse_events(ics, color):
    text = re.sub(r'\r?\n[ \t]', '', ics)
    text = re.sub(r'BEGIN:VALARM.*?END:VALARM\r?\n', '', text, flags=re.S)
    for block in re.findall(r'BEGIN:VEVENT\r?\n(.*?)END:VEVENT', text, re.S):
        fields = {}
        for line in block.splitlines():
            name, _, value = line.partition(':')
            fields.setdefault(name.split(';')[0], value)
        if 'DTSTART' in fields and fields.get('STATUS') != 'CANCELLED':
            title = re.sub(r'\\([\\,;nN])', lambda m: ' ' if m[1] in 'nN' else m[1], fields.get('SUMMARY', ''))
            yield (*parse_start(fields['DTSTART']), title or 'Untitled', color)


def snapshot(events, now):
    events = sorted(events, key=lambda event: event[0])
    upcoming = [event for event in events if (event[0].date() >= now.date() if event[1] else event[0] >= now)]
    days = {}
    for start, _, _, color in events:
        colors = days.setdefault(start.strftime('%Y-%m-%d'), [])
        if color not in colors:
            colors.append(color)
    return {'days': days,
            'upcoming': [{'when': start.strftime('%a %b %-d' if all_day else '%a %b %-d %-I:%M %p'), 'title': title}
                         for start, all_day, title, _ in upcoming[:LIMIT]]}


def fetch(base, user, login, password, now):
    token = base64.b64encode(f'{login}:{password}'.encode()).decode()

    def dav(method, url, body):
        request = Request(url, body.encode(), method=method, headers={
            'Authorization': 'Basic ' + token, 'Depth': '1', 'Content-Type': 'application/xml',
            'User-Agent': 'quickshell-calendar'})
        with urlopen(request, timeout=15) as response:
            return ElementTree.fromstring(response.read())

    home = f'{base}/remote.php/dav/calendars/{user}/'
    window = [(now + timedelta(days=days)).strftime('%Y%m%dT000000Z') for days in (-31, 366)]
    query = QUERY.format(start=window[0], end=window[1])
    events = []
    for item in dav('PROPFIND', home, PROPFIND).iter(DAV + 'response'):
        if item.find(f'.//{DAV}resourcetype/{CALDAV}calendar') is not None:
            color = item.findtext(f'.//{APPLE}calendar-color', '')[:7]
            for data in dav('REPORT', urljoin(home, item.findtext(DAV + 'href')), query).iter(CALDAV + 'calendar-data'):
                events.extend(parse_events(data.text or '', color))
    return events


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
