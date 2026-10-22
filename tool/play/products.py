"""Creates or updates the in-app products in the Play Console from the
shop's real-money items (lib/app/economy.dart). Prices are in US dollars;
Google Play converts them for other countries. Names and descriptions come
from store/listing/<language>/products.json.

  python3 tool/play/products.py
"""
import json
import os
import sys

from play_api import API, PACKAGE, ApiError, call

# id, price (USD cents)
PRODUCTS = [
    ('starter', 99),
    ('gold50', 99),
    ('gold130', 199),
    ('gold350', 499),
    ('gold800', 999),
    ('noads', 299),
    ('pass', 499),
]

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ALSO = {'es-419': ['es-ES', 'es-US']}


def listings(sku):
    """[{languageCode, title, description}] for every translated language."""
    d = os.path.join(ROOT, 'store/listing')
    out = []
    for lang in sorted(os.listdir(d)):
        p = os.path.join(d, lang, 'products.json')
        if not os.path.isfile(p):
            continue
        item = json.load(open(p, encoding='utf-8'))[sku]
        for code in [lang] + ALSO.get(lang, []):
            out.append({'languageCode': code, 'title': item['title'],
                        'description': item['description']})
    return out


def money(cents):
    return {'currencyCode': 'USD', 'units': str(cents // 100),
            'nanos': (cents % 100) * 10_000_000}


def upsert(sku, cents):
    conv = call('POST', f'{API}/pricing:convertRegionPrices',
                {'price': money(cents)})
    version = conv['regionVersion']['version']
    regions = [
        {'regionCode': code, 'price': r['price'], 'availability': 'AVAILABLE'}
        for code, r in sorted(conv['convertedRegionPrices'].items())
    ]
    other = conv.get('convertedOtherRegionsPrice', {})
    option = {
        'purchaseOptionId': 'default',
        # Legacy compatible: what the in_app_purchase plugin buys.
        'buyOption': {'legacyCompatible': True, 'multiQuantityEnabled': False},
        'regionalPricingAndAvailabilityConfigs': regions,
    }
    if other:
        option['newRegionsConfig'] = {
            'usdPrice': other['usdPrice'],
            'eurPrice': other['eurPrice'],
            'availability': 'AVAILABLE',
        }
    body = {
        'packageName': PACKAGE,
        'productId': sku,
        'listings': listings(sku),
        'purchaseOptions': [option],
    }
    call('PATCH', f'{API}/onetimeproducts/{sku}'
         f'?allowMissing=true&regionsVersion.version={version}'
         '&updateMask=listings,purchaseOptions', body)
    call('POST', f'{API}/oneTimeProducts/{sku}/purchaseOptions:batchUpdateStates', {
        'requests': [{'activatePurchaseOptionRequest': {
            'packageName': PACKAGE, 'productId': sku, 'purchaseOptionId': 'default'}}],
    })


def main():
    for sku, cents in PRODUCTS:
        try:
            upsert(sku, cents)
            print(f'{sku}: active at ${cents / 100:.2f}')
        except ApiError as e:
            print(f'{sku}: {e}', file=sys.stderr)
            sys.exit(1)


if __name__ == '__main__':
    main()
