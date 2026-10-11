import 'package:blend_burst/app/app_state.dart';
import 'package:blend_burst/app/economy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a purchase is delivered with its order and turns off ad breaks', () {
    final app = AppState();
    final gold = app.gold;
    app.completePurchase(productById('gold50'), order: 'GPA.1');
    expect(app.gold, gold + 50);
    expect(app.data.orders, {'GPA.1'});
    expect(app.data.adsRemoved, isTrue);
  });

  test('a restored one-time item is remembered but not granted again', () {
    final app = AppState();
    final gold = app.gold;
    app.restorePurchase(productById('starter'), 'GPA.2');
    expect(app.gold, gold);
    expect(app.data.purchases, contains('starter'));
    expect(app.canBuy(productById('starter')), isFalse);
    expect(app.data.orders, contains('GPA.2'));
  });

  test('orders survive a save round-trip and a cloud merge', () {
    final a = SaveData()..orders = {'GPA.1'};
    final b = SaveData()
      ..orders = {'GPA.2'}
      ..unlocked = 4
      ..stars = {1: 3};
    final back = SaveData.fromJson(a.toJson());
    expect(back.orders, {'GPA.1'});
    expect(SaveData.merge(a, b).orders, {'GPA.1', 'GPA.2'});
  });
}
