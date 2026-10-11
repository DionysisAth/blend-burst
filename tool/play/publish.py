"""Uploads an app bundle to a Google Play track.

  python3 tool/play/publish.py app-release.aab --track internal
  python3 tool/play/publish.py app-release.aab --track production --status draft

--status: completed (roll out), draft (prepare in the Play Console) or
inProgress with --fraction for a staged rollout.
"""
import argparse
import sys

from play_api import Edit, call


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('bundle')
    ap.add_argument('--track', default='internal')
    ap.add_argument('--status', default='completed')
    ap.add_argument('--fraction', type=float)
    ap.add_argument('--notes', default='Bug fixes and improvements.')
    ap.add_argument('--name')
    a = ap.parse_args()

    edit = Edit()
    try:
        with open(a.bundle, 'rb') as f:
            b = call('POST', edit.upload_url + '/bundles?uploadType=media',
                     raw=f.read())
        code = b['versionCode']
        print(f'Uploaded bundle, version code {code}')
        release = {
            'versionCodes': [str(code)],
            'status': a.status,
            'releaseNotes': [{'language': 'en-US', 'text': a.notes}],
        }
        if a.name:
            release['name'] = a.name
        if a.fraction:
            release['userFraction'] = a.fraction
        call('PUT', f'{edit.url}/tracks/{a.track}',
             {'track': a.track, 'releases': [release]})
        edit.commit()
        print(f'Released version {code} to the {a.track} track ({a.status})')
    except Exception as e:
        print(e, file=sys.stderr)
        try:
            edit.abandon()
        except Exception:
            pass
        sys.exit(1)


if __name__ == '__main__':
    main()
