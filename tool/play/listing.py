"""Uploads the store listing: texts, contact details, icon, feature graphic
and phone screenshots (from store/). Run from the repo root:

  python3 tool/play/listing.py
"""
import glob
import os
import sys

from play_api import Edit, call

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LANG = 'en-US'
CONTACT_EMAIL = 'chris96skan@gmail.com'
WEBSITE = 'https://www.nwbn.online'


def read(name):
    with open(os.path.join(ROOT, 'store/listing', LANG, name)) as f:
        return f.read().strip()


def images(edit, kind, paths):
    call('DELETE', f'{edit.url}/listings/{LANG}/{kind}')
    for p in paths:
        with open(p, 'rb') as f:
            call('POST', f'{edit.upload_url}/listings/{LANG}/{kind}?uploadType=media',
                 raw=f.read(), content_type='image/png')
        print(f'  {kind}: {os.path.basename(p)}')


def main():
    edit = Edit()
    try:
        call('PUT', f'{edit.url}/details', {
            'defaultLanguage': LANG,
            'contactEmail': CONTACT_EMAIL,
            'contactWebsite': WEBSITE,
        })
        call('PUT', f'{edit.url}/listings/{LANG}', {
            'language': LANG,
            'title': read('title.txt'),
            'shortDescription': read('short.txt'),
            'fullDescription': read('full.txt'),
        })
        print('Texts and contact details set')
        images(edit, 'icon', [os.path.join(ROOT, 'store/icon-512-alpha.png')])
        images(edit, 'featureGraphic', [os.path.join(ROOT, 'store/feature.png')])
        images(edit, 'phoneScreenshots',
               sorted(glob.glob(os.path.join(ROOT, 'store/screenshots/*.png'))))
        edit.commit()
        print('Store listing committed')
    except Exception as e:
        print(e, file=sys.stderr)
        edit.abandon()
        sys.exit(1)


if __name__ == '__main__':
    main()
