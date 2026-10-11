"""Creates or updates the in-app products in the Play Console from the
shop's real-money items (lib/app/economy.dart). Prices are in US dollars;
Google Play converts them for other countries.

  python3 tool/play/products.py
"""
import sys

from play_api import API, PACKAGE, ApiError, call

PRODUCTS = [
    # id, title, description, price (USD cents)
    ('starter', 'Starter Pack', '100 gold, 3 of every booster and 1 hour of unlimited lives. One per player.', 99),
    ('gold50', 'Pouch of Gold', '50 gold', 99),
    ('gold130', 'Bag of Gold', '130 gold', 199),
    ('gold350', 'Chest of Gold', '350 gold', 499),
    ('gold800', 'Vault of Gold', '800 gold', 999),
    ('noads', 'Remove Ads', 'No more ad breaks between levels.', 299),
    ('pass', 'Premium Pass', 'Unlocks the premium track of the current season.', 499),
]


def money(cents):
    return {'currencyCode': 'USD', 'units': str(cents // 100),
            'nanos': (cents % 100) * 10_000_000}


def upsert(sku, title, desc, cents):
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
        'listings': [{'languageCode': 'en-US', 'title': title, 'description': desc}],
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
    for sku, title, desc, cents in PRODUCTS:
        try:
            upsert(sku, title, desc, cents)
            print(f'{sku}: active at ${cents / 100:.2f}')
        except ApiError as e:
            print(f'{sku}: {e}', file=sys.stderr)
            sys.exit(1)


if __name__ == '__main__':
    main()
