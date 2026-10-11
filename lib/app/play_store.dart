import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../screens/dialogs.dart';
import 'app_state.dart';
import 'economy.dart';
import 'store.dart';

/// Google Play billing. The product IDs in the Play Console are the shop
/// product IDs ([shopProducts] paid with money): starter, gold50, gold130,
/// gold350, gold800, noads, pass.
///
/// Every purchase is delivered here, from the purchase stream, so one that
/// completes later (a pending payment, or after the app was closed) is
/// still delivered exactly once. There is no server: purchases are
/// acknowledged on the device.
class PlayStore implements Store {
  final AppState app;
  PlayStore(this.app);

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Only sold once, kept by Google Play (restored on a new install).
  static const _permanent = {'starter', 'noads'};

  static Iterable<Product> get _paid =>
      shopProducts.where((p) => p.pay == PayWith.money);

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _details = <String, ProductDetails>{};
  final _waiting = <String, Completer<bool>>{};
  bool _available = false;
  bool _started = false;

  /// Listens for purchases and loads the products. Call once at startup.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('Purchase stream: $e'),
      );
      await _load();
      // Delivers anything bought but not delivered yet, and restores the
      // one-time items on a new install.
      if (_available) await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Store unavailable: $e');
    }
  }

  Future<void> _load() async {
    try {
      _available = await _iap.isAvailable().timeout(
        const Duration(seconds: 15),
      );
      if (!_available) return;
      final r = await _iap
          .queryProductDetails({for (final p in _paid) p.id})
          .timeout(const Duration(seconds: 20));
      for (final d in r.productDetails) {
        _details[d.id] = d;
      }
      if (r.notFoundIDs.isNotEmpty) {
        debugPrint('Products not in the Play Console: ${r.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('Could not load products: $e');
    }
  }

  @override
  String priceOf(Product p) => _details[p.id]?.price ?? p.priceLabel;

  @override
  Future<bool> buy(BuildContext context, Product product) async {
    if (_details[product.id] == null) await _load();
    final d = _details[product.id];
    if (d == null) {
      if (context.mounted) {
        await confirm(
          context,
          'Store unavailable',
          'Google Play could not be reached. Check your connection and try '
              'again.',
          ok: 'OK',
          cancel: 'Close',
        );
      }
      return false;
    }
    _waiting[product.id]?.complete(false);
    final done = Completer<bool>();
    _waiting[product.id] = done;
    final param = PurchaseParam(productDetails: d);
    bool started;
    try {
      started = _permanent.contains(product.id)
          ? await _iap.buyNonConsumable(purchaseParam: param)
          : await _iap.buyConsumable(purchaseParam: param);
    } catch (e) {
      debugPrint('Purchase failed to start: $e');
      started = false;
    }
    if (!started) {
      _waiting.remove(product.id);
      return false;
    }
    final ok = await done.future.timeout(
      const Duration(minutes: 15),
      onTimeout: () => false,
    );
    _waiting.remove(product.id);
    return ok;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      try {
        await _handle(p);
      } catch (e) {
        debugPrint('Purchase handling failed: $e');
      }
    }
  }

  void _finish(String id, bool ok) {
    final w = _waiting.remove(id);
    if (w != null && !w.isCompleted) w.complete(ok);
  }

  Future<void> _handle(PurchaseDetails p) async {
    final product = shopProducts
        .where((x) => x.id == p.productID && x.pay == PayWith.money)
        .firstOrNull;
    switch (p.status) {
      case PurchaseStatus.pending:
        // Delivered later, when Google Play confirms the payment.
        _finish(p.productID, false);
        return;
      case PurchaseStatus.canceled:
      case PurchaseStatus.error:
        _finish(p.productID, false);
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        if (product != null) _deliver(p, product);
        _finish(p.productID, true);
    }
    if (p.pendingCompletePurchase) await _iap.completePurchase(p);
  }

  void _deliver(PurchaseDetails p, Product product) {
    final order = p.purchaseID ?? '${p.productID}:${p.transactionDate}';
    if (app.data.orders.contains(order)) return;
    // A one-time item that this device already has (restored on a new
    // install via cloud save, or reported again): just remember it.
    final fresh =
        p.status == PurchaseStatus.purchased || p.pendingCompletePurchase;
    if (_permanent.contains(product.id) &&
        (!fresh || app.data.purchases.contains(product.id))) {
      app.restorePurchase(product, order);
      return;
    }
    app.completePurchase(product, order: order);
  }

  void dispose() {
    _sub?.cancel();
    for (final w in _waiting.values) {
      if (!w.isCompleted) w.complete(false);
    }
    _waiting.clear();
  }
}
