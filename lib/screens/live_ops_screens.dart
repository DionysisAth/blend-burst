import 'package:flutter/material.dart';

import '../app/audio.dart';
import '../app/economy.dart';
import '../app/scope.dart';
import '../core/models.dart';
import '../ui/art_cache.dart';
import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';
import '../ui/widgets.dart';
import 'dialogs.dart';
import 'settings_screen.dart' show MenuPage;

// ---------------------------------------------------------------- shared

/// A reward as a row of icons with counts.
class RewardView extends StatelessWidget {
  final Reward reward;
  final double size;
  const RewardView(this.reward, {super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final items = <(Widget, String)>[
      if (reward.coins > 0)
        (GameIcon(GameIcons.coin, size: size), '${reward.coins}'),
      if (reward.gold > 0)
        (GameIcon(GameIcons.gold, size: size), '${reward.gold}'),
      if (reward.lives > 0)
        (GameIcon(GameIcons.heart, size: size), '${reward.lives}'),
      if (reward.unlimitedMinutes > 0)
        (
          GameIcon(GameIcons.unlimited, size: size),
          _minutes(reward.unlimitedMinutes),
        ),
      for (final e in reward.boosters.entries)
        (boosterArt(e.key, size: size), 'x${e.value}'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final (icon, text) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 2),
              GameText(text, size: size * 0.6),
            ],
          ),
      ],
    );
  }
}

String _minutes(int m) => m >= 60 && m % 60 == 0 ? '${m ~/ 60}h' : '${m}m';

String _timeLeft(DateTime end, DateTime now) {
  final d = end.difference(now);
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes.clamp(0, 59)}m';
}

/// "You got ..." celebration for a claimed reward.
Future<void> showRewardDialog(
  BuildContext context,
  Reward reward, {
  String title = 'Reward!',
}) {
  AppScope.read(context).audio.sfx(Sfx.coin);
  return showGameDialog<void>(
    context,
    dismissible: true,
    builder: (ctx) => Stack(
      clipBehavior: Clip.none,
      children: [
        GamePanel(
          title: title,
          ribbonColor: Palette.mint,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameIcon(GameIcons.gift, size: 72),
              const SizedBox(height: 10),
              RewardView(reward, size: 40),
              const SizedBox(height: 16),
              CandyButton.label(
                'Great!',
                key: const Key('reward-ok'),
                colors: CandyColors.green,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
        const Positioned.fill(
          top: -200,
          child: IgnorePointer(child: Confetti(count: 40)),
        ),
      ],
    ),
  );
}

// ----------------------------------------------------------------- daily

/// The login calendar. Shows today's reward and lets the player claim it
/// (doubled after a rewarded ad).
Future<void> showDailyReward(BuildContext context) {
  return showGameDialog<void>(
    context,
    dismissible: true,
    builder: (ctx) => const _DailyPanel(),
  );
}

class _DailyPanel extends StatelessWidget {
  const _DailyPanel();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    final d = app.daily;
    Future<void> claim({required bool doubled}) async {
      final nav = Navigator.of(context);
      if (doubled) {
        final ok = await scope.ads.showRewarded(
          context,
          reward: 'double daily reward',
        );
        if (!ok) return;
      }
      final r = app.claimDaily(doubled: doubled);
      nav.pop();
      if (r != null && context.mounted) {
        await showRewardDialog(context, r, title: 'Day ${d.index + 1}');
      }
    }

    return GamePanel(
      title: 'Daily Gift',
      ribbonColor: Palette.sky,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            d.claimable
                ? 'Come back every day for bigger gifts!'
                : 'Come back tomorrow for day ${(d.index + 1) % 7 + 1}!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Palette.ink,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < dailyRewards.length; i++)
                _DayCell(
                  day: i,
                  reward: dailyRewards[i],
                  state: i < d.index || (!d.claimable && i == d.index)
                      ? _Day.claimed
                      : (i == d.index ? _Day.today : _Day.later),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (d.claimable) ...[
            CandyButton.label(
              'Claim',
              key: const Key('daily-claim'),
              colors: CandyColors.green,
              icon: GameIcons.gift,
              onTap: () => claim(doubled: false),
            ),
            const SizedBox(height: 8),
            CandyButton.label(
              'Watch ad: x2',
              key: const Key('daily-double'),
              colors: CandyColors.blue,
              icon: GameIcons.video,
              height: 48,
              fontSize: 20,
              onTap: () => claim(doubled: true),
            ),
          ] else
            CandyButton.label(
              'OK',
              colors: CandyColors.blue,
              onTap: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}

enum _Day { claimed, today, later }

class _CheckMark extends StatelessWidget {
  const _CheckMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    padding: const EdgeInsets.all(6),
    decoration: const BoxDecoration(
      color: Color(0xFF22B84C),
      shape: BoxShape.circle,
    ),
    child: const GameIcon(GameIcons.check),
  );
}

class _DayCell extends StatelessWidget {
  final int day;
  final Reward reward;
  final _Day state;
  const _DayCell({
    required this.day,
    required this.reward,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final today = state == _Day.today;
    final big = day == dailyRewards.length - 1;
    return Opacity(
      opacity: state == _Day.claimed ? 0.55 : 1,
      child: Container(
        width: big ? 134 : 64,
        height: 80,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: today ? const Color(0xFFFFF3B0) : const Color(0xFFF3E4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: today ? Palette.sun : const Color(0xFFD8BDF5),
            width: today ? 4 : 2,
          ),
        ),
        child: Column(
          children: [
            GameText(
              'Day ${day + 1}',
              size: 14,
              family: 'Fredoka',
              strokeWidth: 3,
            ),
            Expanded(
              child: Center(
                child: state == _Day.claimed
                    ? const _CheckMark()
                    : FittedBox(child: RewardView(reward, size: 26)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ shop

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Future<void> _buy(Product p) async {
    final scope = AppScope.read(context);
    final app = scope.app;
    scope.audio.sfx(Sfx.click);
    if (!app.canBuy(p)) return;
    switch (p.pay) {
      case PayWith.money:
        // The store delivers the item itself (also if the payment
        // completes later).
        final ok = await scope.store.buy(context, p);
        if (!ok || !mounted) return;
      case PayWith.ad:
        final ok = await scope.ads.showRewarded(context, reward: p.subtitle);
        if (!ok || !mounted) return;
        app.buyWithCurrency(p);
      case PayWith.gold:
      case PayWith.coins:
        // Confirm before larger spends.
        if (p.price >= 50 &&
            !await confirm(
              context,
              p.title,
              '${p.subtitle} for ${p.price} ${p.pay == PayWith.gold ? 'gold' : 'coins'}?',
              ok: 'Buy',
            )) {
          return;
        }
        if (!mounted) return;
        if (!app.buyWithCurrency(p)) {
          await confirm(
            context,
            'Not enough ${p.pay == PayWith.gold ? 'gold' : 'coins'}',
            p.pay == PayWith.gold
                ? 'Get more gold from the gold packs, events and the season pass.'
                : 'Win levels to earn more coins!',
            ok: 'OK',
            cancel: 'Close',
          );
          return;
        }
    }
    if (mounted && !p.reward.isEmpty) {
      await showRewardDialog(context, p.reward, title: p.title);
    } else if (mounted) {
      scope.audio.sfx(Sfx.coin);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context).app;
    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: GameText(title, size: 22, color: Palette.sun),
    );
    List<Widget> items(Iterable<String> ids) => [
      for (final id in ids)
        if (app.canBuy(productById(id)) || productById(id).once)
          _ShopItem(
            product: productById(id),
            owned: !app.canBuy(productById(id)),
            onBuy: () => _buy(productById(id)),
          ),
    ];
    return MenuPage(
      title: 'Shop',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Center(
              child: FittedBox(
                child: Row(
                  children: [
                    StatPill(
                      icon: GameIcons.gold,
                      text: '${app.gold}',
                      textKey: const Key('shop-gold'),
                    ),
                    const SizedBox(width: 8),
                    StatPill(icon: GameIcons.coin, text: '${app.coins}'),
                  ],
                ),
              ),
            ),
          ),
          if (app.canBuy(productById('starter'))) ...[
            section('Special offer'),
            ...items(['starter']),
          ],
          section('Gold'),
          ...items(['gold50', 'gold130', 'gold350', 'gold800']),
          section('Lives'),
          ...items(['refill', 'unl30', 'unl60', 'unl180']),
          section('Boosters'),
          ...items(['boosterpack', 'startpack', 'freebooster']),
          section('Extras'),
          ...items(['noads', 'pass']),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Test build: no store is connected, so purchases are free and '
              'only unlock items on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopItem extends StatelessWidget {
  final Product product;
  final bool owned;
  final VoidCallback onBuy;
  const _ShopItem({
    required this.product,
    required this.owned,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = product;
    final icon = switch (p.id) {
      'starter' => GameIcons.gift,
      'noads' => GameIcons.video,
      'pass' => GameIcons.ticket,
      'refill' => GameIcons.heart,
      'unl30' || 'unl60' || 'unl180' => GameIcons.unlimited,
      'boosterpack' => GameIcons.brush,
      'startpack' => GameIcons.splash,
      'freebooster' => GameIcons.video,
      _ => GameIcons.gold,
    };
    final colors = switch (p.pay) {
      PayWith.money => CandyColors.green,
      PayWith.gold => CandyColors.yellow,
      PayWith.coins => CandyColors.yellow,
      PayWith.ad => CandyColors.blue,
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.plum, width: 3),
      ),
      child: Row(
        children: [
          GameIcon(icon, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Palette.ink,
                  ),
                ),
                Text(
                  p.subtitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Color(0xFF6E5A8A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: owned
                ? const Center(
                    child: GameText('Owned', size: 18, color: Palette.mint),
                  )
                : CandyButton(
                    key: Key('buy-${p.id}'),
                    colors: colors,
                    height: 42,
                    onTap: onBuy,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p.pay == PayWith.gold) ...[
                          const GameIcon(GameIcons.gold, size: 22),
                          const SizedBox(width: 2),
                        ],
                        if (p.pay == PayWith.ad) ...[
                          const GameIcon(GameIcons.video, size: 22),
                          const SizedBox(width: 2),
                        ],
                        GameText(
                          p.pay == PayWith.money
                              ? scope.store.priceOf(p)
                              : p.priceLabel,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- event

class EventScreen extends StatelessWidget {
  const EventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    final e = app.event;
    final color = tileColorFromName(e.colorName)!;
    final progress = app.eventProgress;
    final top = WeeklyEvent.tiers.last;
    return MenuPage(
      title: 'Paint Collector',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          GamePanel(
            child: Column(
              children: [
                MiniTile(color: color, size: 64),
                const SizedBox(height: 6),
                GameText(
                  'Collect ${color.label} tiles!',
                  size: 24,
                  color: Palette.sun,
                ),
                const SizedBox(height: 4),
                Text(
                  'Every ${color.label.toLowerCase()} tile you clear in any level counts. '
                  'Ends in ${_timeLeft(e.ends, DateTime.now())}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Palette.ink,
                  ),
                ),
                const SizedBox(height: 12),
                _ProgressBar(value: progress / top, label: '$progress / $top'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < WeeklyEvent.tiers.length; i++)
            _TierRow(
              key: Key('event-tier-$i'),
              label: '${WeeklyEvent.tiers[i]} tiles',
              reward: WeeklyEvent.rewards[i],
              reached: progress >= WeeklyEvent.tiers[i],
              claimed: i < app.data.eventClaimed,
              claimable: i == app.data.eventClaimed && app.eventClaimable > 0,
              onClaim: () async {
                final r = app.claimEventTier();
                if (r != null) await showRewardDialog(context, r);
              },
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final String label;
  const _ProgressBar({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3B1A63),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value.clamp(0.02, 1.0),
                    heightFactor: 1,
                    child: const CachedDecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFFE14D),
                            Color(0xFFFF8A1F),
                            Color(0xFFFF4FA3),
                          ],
                        ),
                      ),
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(child: GameText(label, size: 16)),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final String label;
  final Reward reward;
  final bool reached;
  final bool claimed;
  final bool claimable;
  final VoidCallback onClaim;
  const _TierRow({
    super.key,
    required this.label,
    required this.reward,
    required this.reached,
    required this.claimed,
    required this.claimable,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: reached ? const Color(0xFFFFF3B0) : const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: reached ? Palette.sun : Palette.plum,
          width: 3,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Palette.ink,
              ),
            ),
          ),
          Expanded(child: RewardView(reward, size: 28)),
          SizedBox(
            width: 92,
            child: claimed
                ? const Center(
                    child: GameText('Done', size: 18, color: Palette.mint),
                  )
                : CandyButton.label(
                    'Claim',
                    colors: CandyColors.green,
                    height: 40,
                    fontSize: 18,
                    onTap: claimable ? onClaim : null,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- season

class SeasonPassScreen extends StatelessWidget {
  const SeasonPassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    final season = app.season;
    final points = app.seasonPoints;
    final reached = Season.tiersReached(points);
    final premium = app.premiumPass;
    return MenuPage(
      title: 'Paint Pass',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          GamePanel(
            child: Column(
              children: [
                GameText('Season Rewards', size: 26, color: Palette.sun),
                Text(
                  'Win levels to earn points. Ends in ${_timeLeft(season.ends, DateTime.now())}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Palette.ink,
                  ),
                ),
                const SizedBox(height: 10),
                _ProgressBar(
                  value: reached >= Season.tierCount
                      ? 1
                      : (points % Season.pointsPerTier) / Season.pointsPerTier,
                  label: reached >= Season.tierCount
                      ? 'Complete!'
                      : 'Tier ${reached + 1}: ${points % Season.pointsPerTier} / ${Season.pointsPerTier}',
                ),
                const SizedBox(height: 10),
                if (!premium)
                  CandyButton.label(
                    'Unlock Premium',
                    key: const Key('pass-unlock'),
                    colors: CandyColors.purple,
                    icon: GameIcons.ticket,
                    onTap: () async {
                      final p = productById('pass');
                      await scope.store.buy(context, p);
                    },
                  )
                else
                  const GameText(
                    'Premium unlocked!',
                    size: 20,
                    color: Palette.mint,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              SizedBox(width: 56),
              Expanded(child: Center(child: GameText('Free', size: 18))),
              Expanded(
                child: Center(
                  child: GameText('Premium', size: 18, color: Palette.sun),
                ),
              ),
            ],
          ),
          for (var t = 0; t < Season.tierCount; t++)
            _SeasonRow(tier: t, reached: t < reached, premium: premium),
        ],
      ),
    );
  }
}

class _SeasonRow extends StatelessWidget {
  final int tier;
  final bool reached;
  final bool premium;
  const _SeasonRow({
    required this.tier,
    required this.reached,
    required this.premium,
  });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context).app;
    Widget cell(bool isPremium) {
      final reward = isPremium
          ? Season.premiumReward(tier)
          : Season.freeReward(tier);
      final claimed = app.seasonClaimed(tier, premium: isPremium);
      final can = app.canClaimSeason(tier, premium: isPremium);
      final locked = isPremium && !premium;
      return Expanded(
        child: GestureDetector(
          key: Key('season-$tier-${isPremium ? 'p' : 'f'}'),
          onTap: can
              ? () async {
                  final r = app.claimSeason(tier, premium: isPremium);
                  if (r != null) await showRewardDialog(context, r);
                }
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: claimed ? 0.5 : (locked ? 0.6 : 1),
                child: Container(
                  height: 64,
                  margin: const EdgeInsets.all(3),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: can
                        ? const Color(0xFFFFF3B0)
                        : (isPremium
                              ? const Color(0xFFF3E4FF)
                              : const Color(0xFFFFFBF4)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: can ? Palette.sun : Palette.plum,
                      width: can ? 4 : 2,
                    ),
                  ),
                  child: Center(
                    child: claimed
                        ? const _CheckMark()
                        : FittedBox(child: RewardView(reward, size: 26)),
                  ),
                ),
              ),
              if (locked)
                const Positioned(
                  right: -2,
                  top: -4,
                  child: GameIcon(GameIcons.lock, size: 24),
                ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reached ? Palette.sun : const Color(0xFF6E5A8A),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: GameText('${tier + 1}', size: 18),
            ),
          ),
        ),
        cell(false),
        cell(true),
      ],
    );
  }
}
