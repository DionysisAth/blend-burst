import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/scope.dart';
import '../core/bot.dart';
import '../core/level.dart';
import '../core/models.dart';
import '../l10n/content.dart';
import '../l10n/l10n.dart';
import '../ui/tile_art.dart';
import '../ui/widgets.dart';
import 'game_screen.dart';

enum EditTool {
  playable,
  hole,
  stain,
  glass1,
  glass2,
  glass3,
  switchTile,
  tile,
  clearTile,
  lock1,
  lock2,
  ink,
  bucket,
  filter,
  zone,
  clearOverlay,
}

BotReport _evaluate(LevelDef level) =>
    LevelBot(skill: 0.5, seed: 7).evaluate(level, plays: 12);

/// Runs the bot on a background isolate so the UI stays responsive.
Future<BotReport> evaluateInBackground(LevelDef level) =>
    Isolate.run(() => _evaluate(level));

/// Internal level editor: paint a board, set goals, play-test, export JSON.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  List<List<String>> layout = [];
  List<List<String>> tiles = [];
  List<List<String>> filters = [];
  List<List<String>> zones = [];
  int buckets = 0;
  int bucketsOnBoard = 2;
  int gravityEvery = 0;
  Gravity zoneDir = Gravity.right;
  int id = 100;
  String name = tr.editorCustomLevel;
  int moves = 20;
  List<TileColor> colors = [
    TileColor.red,
    TileColor.blue,
    TileColor.yellow,
    TileColor.brown,
  ];
  Gravity gravity = Gravity.down;
  bool blending = true;
  bool hard = false;
  double switchChance = 0;
  List<Goal> goals = [const Goal(GoalType.score, 10000)];
  List<int> stars = [10000, 20000, 30000];
  String? tutorial;

  EditTool tool = EditTool.stain;
  TileColor toolColor = TileColor.red;
  String? botResult;
  bool botRunning = false;

  @override
  void initState() {
    super.initState();
    _resize(8, 8);
  }

  void _resize(int rows, int cols) {
    List<List<String>> grow(List<List<String>> old) => [
      for (var r = 0; r < rows; r++)
        [
          for (var c = 0; c < cols; c++)
            (r < old.length && c < old[r].length) ? old[r][c] : '.',
        ],
    ];
    setState(() {
      layout = grow(layout);
      tiles = grow(tiles);
      filters = grow(filters);
      zones = grow(zones);
    });
  }

  void _load(LevelDef l) {
    setState(() {
      id = l.id;
      name = l.name;
      moves = l.moves;
      colors = List.of(l.colors);
      gravity = l.gravity;
      blending = l.blending;
      hard = l.hard;
      switchChance = l.switchChance;
      goals = List.of(l.goals);
      stars = List.of(l.stars);
      tutorial = l.tutorial;
      layout = [for (final row in l.layout) row.split('')];
      List<List<String>> grid(List<String>? g) => g == null
          ? [for (final row in l.layout) List.filled(row.length, '.')]
          : [for (final row in g) row.split('')];
      tiles = grid(l.tiles);
      filters = grid(l.filters);
      zones = grid(l.zones);
      buckets = l.buckets;
      bucketsOnBoard = l.bucketsOnBoard;
      gravityEvery = l.gravityEvery;
      botResult = null;
    });
  }

  LevelDef? _build({bool quiet = false}) {
    try {
      bool used(List<List<String>> g) => g.any((r) => r.any((ch) => ch != '.'));
      final hasTiles = used(tiles);
      return LevelDef(
        id: id,
        name: name,
        moves: moves,
        colors: colors,
        layout: [for (final r in layout) r.join()],
        tiles: hasTiles ? [for (final r in tiles) r.join()] : null,
        gravity: gravity,
        blending: blending,
        goals: goals,
        stars: stars,
        switchChance: switchChance,
        hard: hard,
        tutorial: tutorial,
        filters: used(filters) ? [for (final r in filters) r.join()] : null,
        zones: used(zones) ? [for (final r in zones) r.join()] : null,
        buckets: buckets,
        bucketsOnBoard: bucketsOnBoard,
        gravityEvery: gravityEvery,
      );
    } on FormatException catch (e) {
      if (!quiet) _toast(e.message);
      return null;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _paint(int r, int c) {
    if (r < 0 || r >= layout.length || c < 0 || c >= layout[0].length) return;
    setState(() {
      switch (tool) {
        case EditTool.playable:
          layout[r][c] = '.';
        case EditTool.hole:
          layout[r][c] = '#';
          tiles[r][c] = '.';
        case EditTool.stain:
          layout[r][c] = 's';
        case EditTool.glass1:
        case EditTool.glass2:
        case EditTool.glass3:
          layout[r][c] = '${tool.index - EditTool.glass1.index + 1}';
          tiles[r][c] = '.';
        case EditTool.switchTile:
          if ('.s'.contains(layout[r][c])) tiles[r][c] = 'g';
        case EditTool.tile:
          if ('.skK'.contains(layout[r][c])) tiles[r][c] = toolColor.code;
        case EditTool.clearTile:
          tiles[r][c] = '.';
        case EditTool.lock1:
          layout[r][c] = 'k';
        case EditTool.lock2:
          layout[r][c] = 'K';
        case EditTool.ink:
          layout[r][c] = 'i';
          tiles[r][c] = '.';
        case EditTool.bucket:
          if ('.s'.contains(layout[r][c])) {
            tiles[r][c] = 'D';
            if (buckets == 0) buckets = 1;
          }
        case EditTool.filter:
          filters[r][c] = toolColor.code;
        case EditTool.zone:
          zones[r][c] = arrowOf(zoneDir);
        case EditTool.clearOverlay:
          filters[r][c] = '.';
          zones[r][c] = '.';
      }
    });
  }

  Future<void> _copyJson() async {
    final l = _build();
    if (l == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(l.toJson()),
      ),
    );
    if (mounted) _toast(tr.editorJsonCopied);
  }

  Future<void> _importJson() async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData('text/plain');
    controller.text = clip?.text ?? '';
    if (!mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.editorImportTitle),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(tr.editorImport),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    try {
      _load(
        LevelDef.fromJson(Map<String, dynamic>.from(jsonDecode(text) as Map)),
      );
      _toast(tr.editorImported);
    } catch (e) {
      _toast(tr.editorInvalidLevel('$e'));
    }
  }

  void _playTest() {
    final l = _build();
    if (l == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(level: l, testMode: true)),
    );
  }

  Future<void> _runBot() async {
    final l = _build();
    if (l == null || botRunning) return;
    setState(() {
      botRunning = true;
      botResult = null;
    });
    try {
      final r = await evaluateInBackground(l);
      if (mounted) setState(() => botResult = r.toString());
    } catch (e) {
      if (mounted) setState(() => botResult = tr.editorBotFailed('$e'));
    } finally {
      if (mounted) setState(() => botRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = AppScope.of(context).levels.levels;
    final rows = layout.length, cols = layout[0].length;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr.editorTitle),
        actions: [
          PopupMenuButton<int>(
            tooltip: tr.editorLoadLevel,
            icon: const Icon(Icons.folder_open),
            onSelected: (i) => _load(levels[i].copy()),
            itemBuilder: (_) => [
              for (var i = 0; i < levels.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Text('${levels[i].id}. ${levelName(levels[i])}'),
                ),
            ],
          ),
          IconButton(
            tooltip: tr.editorImportJson,
            icon: const Icon(Icons.content_paste),
            onPressed: _importJson,
          ),
          IconButton(
            tooltip: tr.editorCopyJson,
            icon: const Icon(Icons.copy),
            onPressed: _copyJson,
          ),
          IconButton(
            tooltip: tr.editorPlayTest,
            icon: const Icon(Icons.play_arrow),
            onPressed: _playTest,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AspectRatio(
            aspectRatio: cols / rows,
            child: LayoutBuilder(
              builder: (context, box) {
                final cell = box.maxWidth / cols;
                void at(Offset p) =>
                    _paint((p.dy / cell).floor(), (p.dx / cell).floor());
                return GestureDetector(
                  onTapDown: (d) => at(d.localPosition),
                  onPanStart: (d) => at(d.localPosition),
                  onPanUpdate: (d) => at(d.localPosition),
                  child: CustomPaint(
                    size: Size(box.maxWidth, box.maxWidth * rows / cols),
                    painter: _EditorPainter(layout, tiles, filters, zones),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in EditTool.values)
                ChoiceChip(
                  label: Text(switch (t) {
                    EditTool.playable => tr.editorToolCell,
                    EditTool.hole => tr.editorToolHole,
                    EditTool.stain => tr.editorToolStain,
                    EditTool.glass1 => tr.editorToolGlass(1),
                    EditTool.glass2 => tr.editorToolGlass(2),
                    EditTool.glass3 => tr.editorToolGlass(3),
                    EditTool.switchTile => tr.editorToolSwitch,
                    EditTool.tile => tr.editorToolTile,
                    EditTool.clearTile => tr.editorToolRandomTile,
                    EditTool.lock1 => tr.editorToolChain,
                    EditTool.lock2 => tr.editorToolDoubleChain,
                    EditTool.ink => tr.editorToolInk,
                    EditTool.bucket => tr.editorToolBucket,
                    EditTool.filter => tr.editorToolFilter,
                    EditTool.zone => tr.editorToolZone,
                    EditTool.clearOverlay => tr.editorToolClearOverlay,
                  }),
                  selected: tool == t,
                  onSelected: (_) => setState(() => tool = t),
                ),
            ],
          ),
          if (tool == EditTool.zone)
            SegmentedButton<Gravity>(
              segments: const [
                ButtonSegment(
                  value: Gravity.down,
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: Gravity.up,
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: Gravity.left,
                  icon: Icon(Icons.arrow_back),
                ),
                ButtonSegment(
                  value: Gravity.right,
                  icon: Icon(Icons.arrow_forward),
                ),
              ],
              selected: {zoneDir},
              onSelectionChanged: (s) => setState(() => zoneDir = s.first),
            ),
          if (tool == EditTool.tile || tool == EditTool.filter)
            Wrap(
              children: [
                for (final c in TileColor.values)
                  IconButton(
                    isSelected: toolColor == c,
                    style: IconButton.styleFrom(
                      backgroundColor: toolColor == c
                          ? Colors.amber.shade100
                          : null,
                    ),
                    icon: MiniTile(color: c, size: 30),
                    onPressed: () => setState(() => toolColor = c),
                  ),
              ],
            ),
          const Divider(),
          TextFormField(
            initialValue: name,
            key: ValueKey('name-$id-$name'),
            decoration: InputDecoration(labelText: tr.editorName),
            onChanged: (v) => name = v,
          ),
          _stepper(tr.editorRows, rows, 4, 10, (v) => _resize(v, cols)),
          _stepper(tr.editorColumns, cols, 4, 10, (v) => _resize(rows, v)),
          _stepper(
            tr.editorMoves,
            moves,
            5,
            60,
            (v) => setState(() => moves = v),
          ),
          _stepper(
            tr.editorLevelId,
            id,
            1,
            9999,
            (v) => setState(() => id = v),
          ),
          _stepper(
            tr.editorBucketsTotal,
            buckets,
            0,
            20,
            (v) => setState(() => buckets = v),
          ),
          _stepper(
            tr.editorBucketsOnBoard,
            bucketsOnBoard,
            1,
            4,
            (v) => setState(() => bucketsOnBoard = v),
          ),
          _stepper(
            tr.editorGravityEvery,
            gravityEvery,
            0,
            10,
            (v) => setState(() => gravityEvery = v),
          ),
          const SizedBox(height: 8),
          Text(tr.editorGravity),
          SegmentedButton<Gravity>(
            segments: const [
              ButtonSegment(
                value: Gravity.down,
                icon: Icon(Icons.arrow_downward),
              ),
              ButtonSegment(value: Gravity.up, icon: Icon(Icons.arrow_upward)),
              ButtonSegment(value: Gravity.left, icon: Icon(Icons.arrow_back)),
              ButtonSegment(
                value: Gravity.right,
                icon: Icon(Icons.arrow_forward),
              ),
            ],
            selected: {gravity},
            onSelectionChanged: (s) => setState(() => gravity = s.first),
          ),
          SwitchListTile(
            title: Text(tr.editorBlending),
            value: blending,
            onChanged: (v) => setState(() => blending = v),
          ),
          SwitchListTile(
            title: Text(tr.editorHard),
            value: hard,
            onChanged: (v) => setState(() => hard = v),
          ),
          ListTile(
            title: Text(
              tr.editorSwitchChance((switchChance * 100).toStringAsFixed(0)),
            ),
            subtitle: Slider(
              value: switchChance,
              max: 0.1,
              divisions: 10,
              onChanged: (v) => setState(() => switchChance = v),
            ),
          ),
          Text(tr.editorColors),
          Wrap(
            spacing: 4,
            children: [
              for (final c in TileColor.values)
                FilterChip(
                  avatar: MiniTile(color: c, size: 22),
                  label: Text(c.label),
                  selected: colors.contains(c),
                  onSelected: (on) => setState(() {
                    if (on) {
                      colors = [...colors, c];
                    } else if (colors.length > 3) {
                      colors = colors.where((x) => x != c).toList();
                    }
                  }),
                ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr.editorGoals,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(
                  () => goals = [...goals, const Goal(GoalType.stains, 0)],
                ),
                icon: const Icon(Icons.add),
                label: Text(tr.editorAddGoal),
              ),
            ],
          ),
          for (var i = 0; i < goals.length; i++) _goalRow(i),
          const Divider(),
          Text(tr.editorStarThresholds),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: TextFormField(
                      key: ValueKey('star-$i-${stars[i]}-$id'),
                      initialValue: '${stars[i]}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr.editorStarN(i + 1),
                      ),
                      onChanged: (v) => stars[i] = int.tryParse(v) ?? stars[i],
                    ),
                  ),
                ),
            ],
          ),
          TextFormField(
            key: ValueKey('tut-$id-$name'),
            initialValue: tutorial ?? '',
            decoration: InputDecoration(labelText: tr.editorTutorial),
            onChanged: (v) => tutorial = v.trim().isEmpty ? null : v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _playTest,
                icon: const Icon(Icons.play_arrow),
                label: Text(tr.editorPlayTest),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: botRunning ? null : _runBot,
                icon: botRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.smart_toy),
                label: Text(tr.editorBotTest(12)),
              ),
            ],
          ),
          if (botResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(botResult!),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _stepper(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        Expanded(child: Text(tr.editorStepper(label, value))),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _goalRow(int i) {
    final g = goals[i];
    void set(Goal n) => setState(() => goals[i] = n);
    return Row(
      children: [
        DropdownButton<GoalType>(
          value: g.type,
          items: [
            for (final t in GoalType.values)
              DropdownMenuItem(value: t, child: Text(_goalTypeLabel(t))),
          ],
          onChanged: (t) {
            if (t == null) return;
            set(
              Goal(
                t,
                t == GoalType.score ? 10000 : (t == GoalType.collect ? 10 : 0),
                color: t == GoalType.collect ? TileColor.purple : null,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        if (g.type == GoalType.collect)
          DropdownButton<TileColor>(
            value: g.color,
            items: [
              for (final c in TileColor.values)
                DropdownMenuItem(
                  value: c,
                  child: MiniTile(color: c, size: 22),
                ),
            ],
            onChanged: (c) => set(Goal(g.type, g.target, color: c)),
          ),
        Expanded(
          child: TextFormField(
            key: ValueKey('goal-$i-${g.type}-$id'),
            initialValue: '${g.target}',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: g.type == GoalType.score || g.type == GoalType.collect
                  ? tr.editorTarget
                  : tr.editorCount,
            ),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) goals[i] = Goal(g.type, n, color: g.color);
            },
          ),
        ),
        IconButton(
          onPressed: goals.length > 1
              ? () => setState(() => goals.removeAt(i))
              : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

String _goalTypeLabel(GoalType t) => switch (t) {
  GoalType.score => tr.editorGoalScore,
  GoalType.stains => tr.editorGoalStains,
  GoalType.glass => tr.editorGoalGlass,
  GoalType.collect => tr.editorGoalCollect,
  GoalType.locks => tr.editorGoalLocks,
  GoalType.ink => tr.editorGoalInk,
  GoalType.drop => tr.editorGoalDrop,
};

class _EditorPainter extends CustomPainter {
  final List<List<String>> layout;
  final List<List<String>> tiles;
  final List<List<String>> filters;
  final List<List<String>> zones;
  _EditorPainter(this.layout, this.tiles, this.filters, this.zones);

  @override
  void paint(Canvas canvas, Size size) {
    final rows = layout.length, cols = layout[0].length;
    final cell = size.width / cols;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        final ch = layout[r][c];
        if (ch == '#') {
          canvas.drawRect(rect.deflate(1), Paint()..color = Colors.black87);
          continue;
        }
        canvas.drawRect(
          rect.deflate(1),
          Paint()
            ..color = (r + c).isEven
                ? const Color(0xFFEDE7F6)
                : const Color(0xFFD1C4E9),
        );
        final f = tileColorFromCode(filters[r][c]);
        if (f != null) TileArt.filter(canvas, rect, f);
        final z = gravityFromArrow(zones[r][c]);
        if (z != null) TileArt.zoneArrow(canvas, rect, z);
        if (ch == 's') TileArt.stain(canvas, rect);
        if (ch == 'i') TileArt.ink(canvas, rect);
        final t = tiles[r][c];
        final color = tileColorFromCode(t);
        if (t == 'D') {
          TileArt.bucket(canvas, rect.center, cell * 0.38);
        } else if (color != null || t == 'g') {
          TileArt.paint(
            canvas,
            rect.center,
            cell * 0.38,
            color: color ?? TileColor.gray,
            special: Special.none,
            gravitySwitch: t == 'g',
          );
        }
        if (ch == 'k' || ch == 'K') {
          TileArt.chains(canvas, rect, ch == 'K' ? 2 : 1);
        }
        if ('123'.contains(ch)) TileArt.glass(canvas, rect, int.parse(ch));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EditorPainter old) => true;
}
