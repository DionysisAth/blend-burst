"""Uploads the store listing: texts in every language under store/listing/,
contact details, and the icon, feature graphic and phone screenshots (from
store/, shared by all languages). Run from the repo root:

  python3 tool/play/listing.py               # texts and images
  python3 tool/play/listing.py --texts-only
"""
import glob
import os
import sys

from play_api import Edit, call

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LANG = 'en-US'
CONTACT_EMAIL = 'chris96skan@gmail.com'
WEBSITE = 'https://www.nwbn.online'


# One Spanish translation serves Latin America, Spain and the US.
ALSO = {'es-419': ['es-ES', 'es-US']}


def read(name, lang=LANG):
    with open(os.path.join(ROOT, 'store/listing', lang, name), encoding='utf-8') as f:
        return f.read().strip()


def video():
    """The YouTube trailer (store/listing/video.txt), shown in every language."""
    p = os.path.join(ROOT, 'store/listing/video.txt')
    return open(p).read().strip() if os.path.isfile(p) else ''


def languages():
    d = os.path.join(ROOT, 'store/listing')
    return sorted(l for l in os.listdir(d)
                  if os.path.isfile(os.path.join(d, l, 'full.txt')))


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
        for lang in languages():
            texts = {
                'title': read('title.txt', lang),
                'shortDescription': read('short.txt', lang),
                'fullDescription': read('full.txt', lang),
                'video': video(),
            }
            for code in [lang] + ALSO.get(lang, []):
                call('PUT', f'{edit.url}/listings/{code}', {'language': code, **texts})
                print(f'  texts: {code}')
        print('Texts and contact details set')
        if '--texts-only' in sys.argv:
            edit.commit()
            print('Store listing committed')
            return
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
