"""Creates or updates the in-app products in the Play Console from the
shop's real-money items (lib/app/economy.dart). Prices are in US dollars;
Google Play converts them for other countries.

  python3 tool/play/products.py
"""
import sys

from play_api import API, ApiError, call

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


def body(sku, title, desc, cents):
    return {
        'packageName': 'com.nwbn.blendburst',
        'sku': sku,
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultLanguage': 'en-US',
        'defaultPrice': {'priceMicros': str(cents * 10000), 'currency': 'USD'},
        'listings': {'en-US': {'title': title, 'description': desc}},
    }


def main():
    for sku, title, desc, cents in PRODUCTS:
        b = body(sku, title, desc, cents)
        try:
            call('PUT', f'{API}/inappproducts/{sku}?autoConvertMissingPrices=true'
                 '&allowMissing=true', b)
            print(f'{sku}: ok')
        except ApiError as e:
            print(f'{sku}: {e}', file=sys.stderr)
            sys.exit(1)


if __name__ == '__main__':
    main()
