"""Creates the Play Games leaderboards and achievements, then writes their
IDs into the app (lib/app/games_ids.dart and res/values/games.xml).

  python3 tool/play/games_setup.py --project 123456789012

The project ID is the number on Play Console -> Play Games Services ->
Setup and management -> Configuration. Safe to run again: existing
leaderboards and achievements (matched by name) are reused. New ones are
drafts until you publish the Play Games changes in the Play Console.
"""
import argparse
import os
import re
import sys

from play_api import ApiError, call

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
API = 'https://gamesconfiguration.googleapis.com/games/v1configuration'

LEADERBOARDS = [
    ('stars', 'Total Stars'),
    ('levels', 'Levels Completed'),
    ('score', 'Total Score'),
]


def bundle(text):
    return {'translations': [{'locale': 'en-US', 'value': text}]}


def achievements_from_dart():
    src = open(os.path.join(ROOT, 'lib/app/achievements.dart')).read()
    pattern = re.compile(
        r"AchievementDef\(\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*(\d+),", re.S)
    return [(k, n, d, int(p)) for k, n, d, p in pattern.findall(src)]


def listed(path):
    items, token = [], None
    while True:
        url = f'{API}/{path}?maxResults=200' + (f'&pageToken={token}' if token else '')
        r = call('GET', url)
        items += r.get('items', [])
        token = r.get('nextPageToken')
        if not token:
            return items


def name_of(item):
    t = ((item.get('draft') or item.get('published') or {}).get('name') or {})
    return (t.get('translations') or [{}])[0].get('value')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--project', required=True)
    a = ap.parse_args()
    if not re.fullmatch(r'\d{6,}', a.project):
        sys.exit('The project ID is a number, e.g. 123456789012')
    app = f'applications/{a.project}'

    try:
        boards = {name_of(x): x['id'] for x in listed(f'{app}/leaderboards')}
        board_ids = {}
        for rank, (key, name) in enumerate(LEADERBOARDS, 1):
            if name not in boards:
                r = call('POST', f'{API}/{app}/leaderboards', {
                    'scoreOrder': 'LARGER_IS_BETTER',
                    'draft': {
                        'name': bundle(name),
                        'scoreFormat': {'numberFormatType': 'NUMERIC',
                                    'numDecimalPlaces': 0},
                        'sortRank': rank,
                    },
                })
                boards[name] = r['id']
                print(f'Leaderboard created: {name}')
            board_ids[key] = boards[name]

        existing = {name_of(x): x['id'] for x in listed(f'{app}/achievements')}
        achievement_ids = {}
        for rank, (key, name, desc, points) in enumerate(achievements_from_dart(), 1):
            if name not in existing:
                r = call('POST', f'{API}/{app}/achievements', {
                    'achievementType': 'STANDARD',
                    'initialState': 'REVEALED',
                    'draft': {
                        'name': bundle(name),
                        'description': bundle(desc),
                        'pointValue': points,
                        'sortRank': rank,
                    },
                })
                existing[name] = r['id']
                print(f'Achievement created: {name}')
            achievement_ids[key] = existing[name]
    except ApiError as e:
        sys.exit(str(e))

    def dart_map(m):
        return '\n'.join(f"  '{k}': '{v}'," for k, v in m.items())

    with open(os.path.join(ROOT, 'lib/app/games_ids.dart'), 'w') as f:
        f.write(f"""// Google Play Games IDs, written by tool/play/games_setup.py. Do not edit by
// hand: run the script again instead. Empty IDs switch the feature off.

/// The Play Games project ID (also in android/.../res/values/games.xml).
const playGamesProjectId = '{a.project}';

/// Leaderboard IDs by key (stars, levels, score).
const playLeaderboards = <String, String>{{
{dart_map(board_ids)}
}};

/// Achievement IDs by key (see achievements.dart).
const playAchievements = <String, String>{{
{dart_map(achievement_ids)}
}};
""")
    xml = os.path.join(ROOT, 'android/app/src/main/res/values/games.xml')
    s = open(xml).read()
    s = re.sub(r'(name="game_services_project_id"[^>]*>)[^<]*(<)', rf'\g<1>{a.project}\2', s)
    open(xml, 'w').write(s)
    print(f'Wrote {len(board_ids)} leaderboards and {len(achievement_ids)} achievements '
          'into lib/app/games_ids.dart and games.xml')


if __name__ == '__main__':
    main()
