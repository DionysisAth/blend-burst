"""Fills in the Play Console data safety form and uploads it.

  python3 tool/play/data_safety.py TEMPLATE.csv [--upload]

TEMPLATE.csv is the form exported from Play Console -> App content ->
Data safety -> Export to CSV. The answers below describe what the game and
its SDKs (AdMob, Firebase Analytics and Crashlytics, Play Games Services,
Play Billing) do; keep them in sync
with the privacy policy. Writes store/data-safety/data_safety.csv.
"""
import csv
import io
import os
import sys

from play_api import API, call

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
POLICY = 'https://www.nwbn.online/blendburst/privacy-policy'

ADS = ['PSL_ADVERTISING', 'PSL_ANALYTICS', 'PSL_FRAUD_PREVENTION_SECURITY']

# data type -> (collected, shared, required, collection purposes, sharing purposes)
DATA = {
    # Google Mobile Ads SDK (AdMob).
    'PSL_DEVICE_ID': (True, True, True, ADS, ADS),
    'PSL_APPROX_LOCATION': (True, True, True, ADS, ADS),
    'PSL_USER_INTERACTION': (True, True, True,
                             ['PSL_ADVERTISING', 'PSL_ANALYTICS'],
                             ['PSL_ADVERTISING', 'PSL_ANALYTICS']),
    'PSL_PERFORMANCE_DIAGNOSTICS': (True, True, True,
                                    ['PSL_ANALYTICS', 'PSL_FRAUD_PREVENTION_SECURITY'],
                                    ['PSL_ANALYTICS', 'PSL_FRAUD_PREVENTION_SECURITY']),
    # Firebase Crashlytics (crash reports; Firebase Analytics adds nothing
    # new: app interactions, diagnostics and an app instance ID are above).
    'PSL_CRASH_LOGS': (True, False, True,
                       ['PSL_ANALYTICS', 'PSL_APP_FUNCTIONALITY'], []),
    # Optional Google Play Games sign-in: player ID, cloud save, scores.
    'PSL_USER_ACCOUNT': (True, False, False, ['PSL_APP_FUNCTIONALITY'], []),
    'PSL_OTHER_APP_ACTIVITY': (True, False, False, ['PSL_APP_FUNCTIONALITY'], []),
    # Google Play purchases (order IDs kept with the progress).
    'PSL_PURCHASE_HISTORY': (True, False, False, ['PSL_APP_FUNCTIONALITY'], []),
}

TYPE_GROUP = {
    'PSL_DEVICE_ID': 'PSL_DATA_TYPES_IDENTIFIERS',
    'PSL_APPROX_LOCATION': 'PSL_DATA_TYPES_LOCATION',
    'PSL_USER_INTERACTION': 'PSL_DATA_TYPES_APP_ACTIVITY',
    'PSL_OTHER_APP_ACTIVITY': 'PSL_DATA_TYPES_APP_ACTIVITY',
    'PSL_PERFORMANCE_DIAGNOSTICS': 'PSL_DATA_TYPES_APP_PERFORMANCE',
    'PSL_CRASH_LOGS': 'PSL_DATA_TYPES_APP_PERFORMANCE',
    'PSL_USER_ACCOUNT': 'PSL_DATA_TYPES_PERSONAL',
    'PSL_PURCHASE_HISTORY': 'PSL_DATA_TYPES_FINANCIAL',
}


def answer(q, r):
    """The value for question q / response r, or None to leave it empty."""
    simple = {
        ('PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA', ''): 'true',
        ('PSL_DATA_COLLECTION_ENCRYPTED_IN_TRANSIT', ''): 'true',
        ('PSL_SUPPORTED_ACCOUNT_CREATION_METHODS', 'PSL_ACM_NONE'): 'true',
        ('PSL_SUPPORT_DATA_DELETION_BY_USER', 'DATA_DELETION_YES'): 'true',
        ('PSL_DATA_DELETION_URL', ''): POLICY,
    }
    if (q, r) in simple:
        return simple[(q, r)]
    for t, group in TYPE_GROUP.items():
        if q == group and r == t:
            return 'true'
    if q.startswith('PSL_DATA_USAGE_RESPONSES:'):
        _, t, part = q.split(':')
        if t not in DATA:
            return None
        collected, shared, required, cpurp, spurp = DATA[t]
        if part == 'PSL_DATA_USAGE_COLLECTION_AND_SHARING':
            if r == 'PSL_DATA_USAGE_ONLY_COLLECTED' and collected:
                return 'true'
            if r == 'PSL_DATA_USAGE_ONLY_SHARED' and shared:
                return 'true'
        elif part == 'PSL_DATA_USAGE_EPHEMERAL':
            return 'false'
        elif part == 'DATA_USAGE_USER_CONTROL':
            want = ('PSL_DATA_USAGE_USER_CONTROL_REQUIRED' if required
                    else 'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL')
            if r == want:
                return 'true'
        elif part == 'DATA_USAGE_COLLECTION_PURPOSE' and r in cpurp:
            return 'true'
        elif part == 'DATA_USAGE_SHARING_PURPOSE' and r in spurp:
            return 'true'
    return None


def main():
    src = sys.argv[1]
    rows = list(csv.reader(open(src, encoding='utf-8')))
    header, body = rows[0], rows[1:]
    filled = 0
    for row in body:
        v = answer(row[0], row[1])
        row[2] = v or ''
        filled += v is not None
    out = io.StringIO()
    csv.writer(out, lineterminator='\n').writerows([header] + body)
    text = out.getvalue()
    path = os.path.join(ROOT, 'store/data-safety/data_safety.csv')
    open(path, 'w', encoding='utf-8').write(text)
    print(f'Filled {filled} answers -> {path}')
    if '--upload' in sys.argv:
        call('POST', f'{API}/dataSafety', {'safetyLabels': text})
        print('Uploaded to the Play Console')


if __name__ == '__main__':
    main()
