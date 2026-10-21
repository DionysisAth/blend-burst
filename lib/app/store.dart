import 'package:flutter/material.dart';

import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';
import '../l10n/l10n.dart';
import 'economy.dart';
import 'scope.dart';

/// Real-money purchases. On Android this is Google Play billing
/// (`PlayStore`); tests and other platforms use [TestStore], which completes
/// every purchase for free after saying so.
abstract class Store {
  /// Shows the purchase flow and delivers [product] to the player. True
  /// when it was bought and delivered.
  Future<bool> buy(BuildContext context, Product product);

  /// The price to show, localized by the store when it knows it.
  String priceOf(Product product);
}

class TestStore implements Store {
  const TestStore();

  @override
  String priceOf(Product product) => product.priceLabel;

  @override
  Future<bool> buy(BuildContext context, Product product) async {
    final ok = await showGameDialog<bool>(
      context,
      dismissible: true,
      builder: (ctx) => GamePanel(
        title: tr.storeTestTitle,
        ribbonColor: Palette.mint,
        onClose: () => Navigator.of(ctx).pop(false),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameIcon(GameIcons.shop, size: 64),
            const SizedBox(height: 8),
            GameText(product.title, size: 24, color: Palette.sun),
            const SizedBox(height: 4),
            Text(
              tr.storeTestBody(product.subtitle, product.priceLabel),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Palette.ink,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            CandyButton.label(
              tr.storeTestConfirm,
              key: const Key('store-confirm'),
              colors: CandyColors.green,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return false;
    AppScope.read(context).app.completePurchase(product);
    return true;
  }
}
