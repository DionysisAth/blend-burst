import 'package:flutter/material.dart';

import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';
import 'economy.dart';

/// Real-money purchases (App Store / Google Play billing).
///
/// This build has no store accounts connected, so [TestStore] completes
/// every purchase for free after saying so. A billing implementation (for
/// example with the in_app_purchase plugin and receipt validation) replaces
/// it without touching the shop screens.
abstract class Store {
  /// Shows the purchase flow; true when [product] was bought.
  Future<bool> buy(BuildContext context, Product product);
}

class TestStore implements Store {
  const TestStore();

  @override
  Future<bool> buy(BuildContext context, Product product) async {
    final ok = await showGameDialog<bool>(
      context,
      dismissible: true,
      builder: (ctx) => GamePanel(
        title: 'Test purchase',
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
              '${product.subtitle}\n\nPrice in the stores: ${product.priceLabel}.\n'
              'This test build has no store connected: you will not be '
              'charged.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Palette.ink,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            CandyButton.label(
              'Get it (free test)',
              key: const Key('store-confirm'),
              colors: CandyColors.green,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }
}
