#!/usr/bin/env python3
"""Generates levels 41..120 (the end of Paint Factory and episodes 4..8).

Each level is designed here explicitly: board shape, obstacle pattern,
goals, colors and gravity rules. Move limits and star thresholds are
placeholders; tune them with the bot afterwards:

    python3 tool/levels/make_levels.py
    dart run tool/level_bot.dart --tune --plays 20
    dart run tool/level_bot.dart --calibrate --plays 20

Levels 1..40 are hand-made and are not touched (episode3.json keeps its
first ten levels and gets 41..45 appended).
"""
import json
import os

N = 8

# ------------------------------------------------------------------ shapes

SHAPES = {
    'full': ['........'] * 8,
    'notch': ['#......#', '........', '........', '........', '........', '........', '........', '#......#'],
    'diamond': ['##....##', '#......#', '........', '........', '........', '........', '#......#', '##....##'],
    'hourglass': ['........', '#......#', '##....##', '###..###', '###..###', '##....##', '#......#', '........'],
    'cross': ['##....##', '##....##', '........', '........', '........', '........', '##....##', '##....##'],
    'pillars': ['........', '........', '.#....#.', '.#....#.', '.#....#.', '.#....#.', '........', '........'],
    'frame': ['........', '........', '..#..#..', '........', '........', '..#..#..', '........', '........'],
    'heart': ['#..##..#', '........', '........', '........', '........', '#......#', '##....##', '###..###'],
    'arch': ['........', '........', '........', '...##...', '..#..#..', '........', '........', '........'],
    'twins': ['....#...', '....#...', '....#...', '........', '........', '...#....', '...#....', '...#....'],
    'ring': ['........', '........', '..####..', '..#..#..', '..#..#..', '..####..', '........', '........'],
    'tall': ['#......#', '#......#', '#......#', '#......#', '#......#', '#......#', '#......#', '#......#'],
}


def grid(rows):
    return [list(r) for r in rows]


def rows(g):
    return [''.join(r) for r in g]


def put(g, cells, ch, only_on='.'):
    for r, c in cells:
        if 0 <= r < N and 0 <= c < N and g[r][c] in only_on:
            g[r][c] = ch


def mirror4(cells):
    """Mirror cells left-right and top-bottom (symmetric designs)."""
    out = set()
    for r, c in cells:
        for rr in (r, N - 1 - r):
            for cc in (c, N - 1 - c):
                out.add((rr, cc))
    return sorted(out)


def mirror2(cells):
    out = set()
    for r, c in cells:
        out.add((r, c))
        out.add((r, N - 1 - c))
    return sorted(out)


def rect(r0, c0, r1, c1):
    return [(r, c) for r in range(r0, r1 + 1) for c in range(c0, c1 + 1)]


def border():
    return [(r, c) for r in range(N) for c in range(N) if r in (0, N - 1) or c in (0, N - 1)]


def checker(r0, c0, r1, c1, parity=0):
    return [(r, c) for r, c in rect(r0, c0, r1, c1) if (r + c) % 2 == parity]


def row_cells(r):
    return [(r, c) for c in range(N)]


def col_cells(c):
    return [(r, c) for r in range(N)]


def empty():
    return ['........'] * 8


COLORS = {
    4: ['red', 'blue', 'yellow', 'brown'],
    5: ['red', 'blue', 'yellow', 'brown', 'gray'],
    6: ['red', 'blue', 'yellow', 'purple', 'brown', 'gray'],
}


def level(lid, name, shape, goals, *, colors=5, layout_fn=None, tiles=None,
          filters=None, zones=None, gravity='down', switch=0.0, buckets=0,
          on_board=2, every=0, hard=False, tutorial=None, art=None):
    g = grid(SHAPES[shape])
    if layout_fn:
        layout_fn(g)
    d = {
        'id': lid,
        'name': name,
        'moves': 25,
        'colors': COLORS[colors] if isinstance(colors, int) else colors,
        'layout': rows(g),
        'goals': goals,
        'stars': [10000, 20000, 30000],
    }
    if tiles:
        t = grid(empty())
        for (r, c), ch in tiles.items():
            if g[r][c] not in '#123i':
                t[r][c] = ch
        d['tiles'] = rows(t)
    if filters:
        f = grid(empty())
        for (r, c), ch in filters.items():
            if g[r][c] != '#':
                f[r][c] = ch
        d['filters'] = rows(f)
    if zones:
        z = grid(empty())
        for (r, c), ch in zones.items():
            if g[r][c] != '#':
                z[r][c] = ch
        d['zones'] = rows(z)
    if gravity != 'down':
        d['gravity'] = gravity
    if switch:
        d['switchChance'] = switch
    if buckets:
        d['buckets'] = buckets
        if on_board != 2:
            d['bucketsOnBoard'] = on_board
    if every:
        d['gravityEvery'] = every
    if hard:
        d['hard'] = True
    if tutorial:
        d['tutorial'] = tutorial
    if art:
        d['tutorialArt'] = art
    return d


def G(t, target=None, color=None):
    g = {'type': t}
    if target is not None:
        g['target'] = target
    if color:
        g['color'] = color
    return g


def L(ch, cells):
    return lambda g: put(g, cells, ch)


def chain(*fns):
    def f(g):
        for fn in fns:
            fn(g)
    return f


# ------------------------------------------------------- paint factory end

factory = [
    level(41, 'Clockwork', 'full', [G('stains')],
          layout_fn=L('s', rect(2, 2, 5, 5)), every=4,
          tutorial='These gears turn on their own! Gravity rotates every few moves; the counter by the arrow shows when.',
          art='timed'),
    level(42, 'Flip Switch', 'notch', [G('glass'), G('score', 25000)],
          layout_fn=L('1', mirror4([(1, 2), (2, 1), (3, 3)])), gravity='left',
          tutorial='New booster: Gravity Flip! Choose where tiles fall for your next move.',
          art='flip'),
    level(43, 'Conveyor Belts', 'full', [G('stains')],
          layout_fn=L('s', rect(0, 0, 1, 7) + rect(6, 0, 7, 7)),
          zones={**{(2, c): '>' for c in range(N)}, **{(5, c): '<' for c in range(N)}},
          tutorial='Arrows on cells are gravity zones: tiles there fall the way the arrow points.',
          art='zones'),
    level(44, 'Spin Dryer', 'diamond', [G('glass'), G('stains')],
          layout_fn=chain(L('2', mirror4([(2, 2)])), L('s', mirror4([(3, 0), (0, 3)]))),
          every=3, switch=0.04),
    level(45, 'Factory Finale', 'cross', [G('glass'), G('stains')], colors=6,
          layout_fn=chain(L('s', rect(3, 0, 4, 7)), L('2', mirror4([(2, 2), (0, 2)]))),
          zones={**{(r, 3): 'v' for r in range(3)}, **{(r, 4): 'v' for r in range(3)}},
          every=5, hard=True),
]

# ----------------------------------------------------------- sky gallery

sky = [
    level(46, 'Chained Canvas', 'full', [G('locks')], colors=4,
          layout_fn=L('k', rect(3, 2, 4, 5)),
          tutorial='Chained tiles cannot move. Match them (or blast them) to break the chains!',
          art='lock'),
    level(47, 'Gallery Wall', 'full', [G('locks')], layout_fn=L('k', mirror4([(1, 1), (1, 3), (3, 1), (3, 3)]))),
    level(48, 'Double Bolted', 'notch', [G('locks')],
          layout_fn=chain(L('K', mirror4([(2, 2)])), L('k', mirror4([(3, 3), (1, 3)]))),
          tutorial='Gold padlocks have two chains: break them twice.'),
    level(49, 'Hanging Frames', 'pillars', [G('locks'), G('score', 20000)],
          layout_fn=L('k', [(0, c) for c in range(N)])),
    level(50, 'Vault', 'ring', [G('locks'), G('glass')],
          layout_fn=chain(L('k', mirror4([(1, 2)])), L('1', mirror4([(0, 0)]))), hard=True),
    level(51, 'Skylight', 'diamond', [G('locks'), G('stains')],
          layout_fn=chain(L('s', rect(2, 2, 5, 5)), L('k', mirror4([(1, 2), (2, 1)])))),
    level(52, 'Cloud Steps', 'full', [G('locks')], layout_fn=L('k', [(r, r) for r in range(N)] + [(r, N - 1 - r) for r in range(N)])),
    level(53, 'Portrait', 'heart', [G('locks'), G('collect', 18, 'purple')], colors=6,
          layout_fn=L('k', mirror2([(2, 2), (3, 3), (4, 3)]))),
    level(54, 'Exhibit', 'frame', [G('glass'), G('locks')],
          layout_fn=chain(L('1', mirror4([(3, 3)])), L('k', mirror4([(1, 1)])))),
    level(55, 'Locked Wing', 'cross', [G('locks')], layout_fn=chain(L('k', mirror4([(2, 0), (2, 3)])), L('K', mirror4([(3, 1)]))), hard=True),
    level(56, 'Open Air', 'full', [G('score', 35000), G('locks')], layout_fn=L('k', checker(3, 0, 4, 7))),
    level(57, 'Sky Bridge', 'hourglass', [G('locks'), G('stains')],
          layout_fn=chain(L('s', rect(0, 0, 1, 7)), L('k', [(3, 3), (3, 4), (4, 3), (4, 4)]))),
    level(58, 'Wind Chimes', 'twins', [G('locks')], layout_fn=L('k', mirror4([(2, 2), (1, 1)]))),
    level(59, 'Curator', 'notch', [G('locks'), G('glass'), G('stains')], colors=6,
          layout_fn=chain(L('s', rect(3, 0, 4, 7)), L('1', mirror4([(1, 2)])), L('k', mirror4([(2, 1), (2, 3)])))),
    level(60, 'Grand Gallery', 'full', [G('locks')], colors=5,
          layout_fn=chain(L('K', rect(3, 3, 4, 4)), L('k', mirror4([(0, 0), (0, 3), (3, 0)]))), hard=True),
]

# ------------------------------------------------------------- ink lagoon

lagoon = [
    level(61, 'Inkwell', 'full', [G('ink')], colors=4, layout_fn=L('i', [(3, 3), (3, 4), (4, 3), (4, 4)]),
          tutorial='Ink spreads every move you do not clear any! Match next to it to wipe it out.',
          art='ink'),
    level(62, 'Spill', 'full', [G('ink')], layout_fn=L('i', mirror4([(0, 0), (0, 1), (1, 0)]))),
    level(63, 'Tide Pool', 'diamond', [G('ink'), G('score', 20000)], layout_fn=L('i', rect(3, 2, 4, 5))),
    level(64, 'Squid Trail', 'full', [G('ink'), G('stains')],
          layout_fn=chain(L('s', rect(0, 0, 1, 7)), L('i', [(6, c) for c in range(N)]))),
    level(65, 'Black Lagoon', 'notch', [G('ink')], layout_fn=L('i', rect(2, 2, 5, 5)), hard=True),
    level(66, 'Coral', 'pillars', [G('ink'), G('locks')],
          layout_fn=chain(L('i', [(7, 3), (7, 4)]), L('k', mirror4([(3, 3)])))),
    level(67, 'Ink Rings', 'arch', [G('ink')], colors=4, layout_fn=L('i', mirror4([(1, 2)]))),
    level(68, 'Shoreline', 'full', [G('ink'), G('glass')],
          layout_fn=chain(L('1', row_cells(4)), L('i', rect(6, 0, 7, 1) + rect(6, 6, 7, 7)))),
    level(69, 'Deep Current', 'tall', [G('ink')], colors=5,
          layout_fn=L('i', [(r, 3) for r in range(2, 6)] + [(r, 4) for r in range(2, 6)]),
          zones={**{(r, 1): '>' for r in range(N)}, **{(r, 6): '<' for r in range(N)}}),
    level(70, 'Kraken', 'cross', [G('ink'), G('locks')], colors=6,
          layout_fn=chain(L('i', rect(3, 3, 4, 4) + mirror4([(0, 2)])), L('K', mirror4([(2, 2)]))), hard=True),
    level(71, 'Low Tide', 'full', [G('ink'), G('collect', 15, 'green')], colors=5, layout_fn=L('i', checker(6, 0, 7, 7))),
    level(72, 'Bottle Message', 'hourglass', [G('ink'), G('stains')],
          layout_fn=chain(L('s', rect(0, 1, 0, 6)), L('i', rect(7, 2, 7, 5)))),
    level(73, 'Riptide', 'full', [G('ink')], layout_fn=L('i', mirror4([(0, 3), (1, 2), (2, 1), (3, 0)])), gravity='up'),
    level(74, 'Pearl Diver', 'heart', [G('ink'), G('glass'), G('locks')],
          layout_fn=chain(L('i', mirror2([(1, 1), (1, 2)])), L('2', [(4, 3), (4, 4)]), L('k', mirror2([(3, 2)])))),
    level(75, 'Lagoon Storm', 'full', [G('ink')], colors=5, layout_fn=L('i', border()), every=4, hard=True),
]

# ------------------------------------------------------------ prism peaks

peaks = [
    level(76, 'Tinted Glass', 'full', [G('collect', 20, 'purple')], colors=['red', 'blue', 'yellow', 'brown'],
          filters=dict.fromkeys([(2, 1), (2, 3), (2, 5)], 'P'),
          tutorial='Color filters paint any tile that falls into them. Use them to collect colors!',
          art='filter'),
    level(77, 'Rainbow Ridge', 'full', [G('collect', 18, 'green'), G('collect', 18, 'orange')],
          colors=['red', 'blue', 'yellow', 'brown'],
          filters={**dict.fromkeys([(3, 0), (3, 2)], 'G'), **dict.fromkeys([(3, 5), (3, 7)], 'O')}),
    level(78, 'Crystal Cave', 'diamond', [G('stains'), G('collect', 15, 'blue')],
          layout_fn=L('s', rect(5, 1, 7, 6)), filters=dict.fromkeys(mirror2([(2, 2)]), 'B')),
    level(79, 'Prism Pass', 'pillars', [G('collect', 22, 'red')], filters=dict.fromkeys([(1, 1), (1, 3), (1, 5)], 'R')),
    level(80, 'Spectrum', 'full', [G('collect', 15, 'purple'), G('collect', 15, 'green'), G('collect', 15, 'orange')],
          colors=['red', 'blue', 'yellow', 'brown'],
          filters={**dict.fromkeys([(2, 0), (2, 2)], 'P'), (2, 4): 'G', (2, 6): 'O'},
          hard=True),
    level(81, 'Glacier', 'cross', [G('glass'), G('collect', 18, 'blue')],
          layout_fn=L('1', mirror4([(3, 0), (3, 1)])), filters=dict.fromkeys([(1, 2), (1, 5)], 'B')),
    level(82, 'Summit', 'notch', [G('locks'), G('collect', 18, 'yellow')],
          layout_fn=L('k', rect(5, 2, 6, 5)), filters=dict.fromkeys(mirror2([(2, 1)]), 'Y')),
    level(83, 'Opal Steps', 'hourglass', [G('stains')], colors=5,
          layout_fn=L('s', rect(6, 0, 7, 7)), filters={(2, 2): 'R', (2, 5): 'R'}),
    level(84, 'Lens', 'frame', [G('collect', 14, 'purple'), G('ink')], colors=['red', 'blue', 'yellow', 'brown'],
          layout_fn=L('i', mirror4([(0, 0)])), filters=dict.fromkeys(mirror4([(1, 2)]), 'P')),
    level(85, 'Aurora', 'full', [G('collect', 24, 'green'), G('locks')], colors=['red', 'blue', 'yellow', 'gray'],
          layout_fn=L('K', mirror4([(3, 1)])), filters=dict.fromkeys([(4, 1), (4, 3), (4, 5)], 'G'), hard=True),
    level(86, 'Geode', 'diamond', [G('glass'), G('stains')],
          layout_fn=chain(L('2', [(3, 3), (3, 4), (4, 3), (4, 4)]), L('s', mirror4([(2, 1), (1, 2)]))),
          filters=dict.fromkeys(mirror2([(0, 2)]), 'O')),
    level(87, 'Kaleidoscope', 'full', [G('collect', 18, 'purple'), G('collect', 18, 'orange')],
          colors=['red', 'blue', 'yellow', 'brown'],
          filters={**dict.fromkeys(mirror4([(1, 1)]), 'P'), **dict.fromkeys([(3, 3), (4, 4)], 'O')}, gravity='up'),
    level(88, 'Snowcap', 'tall', [G('stains'), G('ink')], layout_fn=chain(L('s', rect(0, 1, 2, 6)), L('i', [(6, 3), (6, 4)])),
          filters=dict.fromkeys([(4, 2), (4, 5)], 'Y')),
    level(89, 'Prism Heart', 'heart', [G('collect', 20, 'red'), G('locks'), G('glass')], colors=6,
          layout_fn=chain(L('k', mirror2([(2, 1), (2, 2)])), L('1', [(4, 3), (4, 4)])),
          filters=dict.fromkeys(mirror2([(1, 2)]), 'R')),
    level(90, 'Peak of Colors', 'full', [G('collect', 20, 'purple'), G('collect', 20, 'green'), G('ink')],
          colors=['red', 'blue', 'yellow', 'brown'], layout_fn=L('i', rect(6, 2, 7, 5)),
          filters={**dict.fromkeys([(2, 1), (2, 6)], 'P'), **dict.fromkeys([(3, 3), (3, 5)], 'G')},
          hard=True),
]

# --------------------------------------------------------- bucket brigade

def D(*cells):
    return dict.fromkeys(cells, 'D')


brigade = [
    level(91, 'First Delivery', 'full', [G('drop')], colors=4, tiles=D((0, 3), (0, 4)), buckets=2,
          tutorial='Bring the paint buckets to the exit, the glowing edge in the gravity direction!',
          art='bucket'),
    level(92, 'Bucket Line', 'full', [G('drop')], buckets=4),
    level(93, 'Paint Run', 'pillars', [G('drop'), G('stains')], layout_fn=L('s', rect(6, 0, 7, 7)), buckets=3),
    level(94, 'Downhill', 'diamond', [G('drop')], tiles=D((1, 2), (1, 5)), buckets=5),
    level(95, 'Heavy Load', 'full', [G('drop'), G('glass')], layout_fn=L('2', rect(4, 2, 4, 5)), buckets=4, hard=True),
    level(96, 'Upward Pour', 'full', [G('drop')], gravity='up', buckets=4,
          tutorial='Gravity is up here, so the exit is at the top!'),
    level(97, 'Chained Cargo', 'notch', [G('drop'), G('locks')], layout_fn=L('k', rect(3, 1, 3, 6)), buckets=4),
    level(98, 'Side Chute', 'full', [G('drop')], gravity='right', buckets=3),
    level(99, 'Ink Spill', 'full', [G('drop'), G('ink')], layout_fn=L('i', mirror2([(4, 0), (4, 1)])), buckets=4),
    level(100, 'Century', 'cross', [G('drop'), G('stains'), G('glass')], colors=6,
           layout_fn=chain(L('s', rect(0, 2, 1, 5)), L('1', mirror4([(3, 0)]))), buckets=5, hard=True),
    level(101, 'Turntable', 'full', [G('drop')], buckets=5, every=4),
    level(102, 'Switchback', 'hourglass', [G('drop')], buckets=4, switch=0.04, tiles={(0, 1): 'g', (0, 6): 'g'}),
    level(103, 'Funnel', 'diamond', [G('drop')], buckets=4),
    level(104, 'Color Pipeline', 'full', [G('drop'), G('collect', 20, 'orange')], colors=['red', 'blue', 'yellow', 'brown'],
           buckets=4, filters=dict.fromkeys([(3, 2), (3, 5)], 'O')),
    level(105, 'Brigade Finale', 'full', [G('drop'), G('locks'), G('ink')], colors=5,
           layout_fn=chain(L('k', mirror4([(2, 2), (3, 1)])), L('i', [(5, 3), (5, 4)])), buckets=6, every=5, hard=True),
]

# --------------------------------------------------------- gravity galaxy

galaxy = [
    level(106, 'Orbit', 'ring', [G('stains')], layout_fn=L('s', border()),
          zones={**{(0, c): '>' for c in range(7)}, **{(r, 7): 'v' for r in range(7)},
                 **{(7, c): '<' for c in range(1, 8)}, **{(r, 0): '^' for r in range(1, 8)}}),
    level(107, 'Comet Tail', 'full', [G('ink'), G('drop')], layout_fn=L('i', rect(0, 0, 0, 7)), buckets=3, every=3),
    level(108, 'Moon Phases', 'diamond', [G('locks'), G('glass')],
          layout_fn=chain(L('K', mirror4([(3, 2)])), L('1', mirror4([(1, 2), (2, 1)]))), every=4),
    level(109, 'Black Hole', 'full', [G('ink')], colors=5, layout_fn=L('i', rect(3, 3, 4, 4)),
          zones={**{(r, c): 'v' for r in range(0, 3) for c in range(N)}, **{(r, c): '^' for r in range(5, 8) for c in range(N)}}),
    level(110, 'Supernova', 'cross', [G('collect', 20, 'purple'), G('locks'), G('stains')], colors=6,
          layout_fn=chain(L('s', rect(3, 0, 4, 7)), L('k', mirror4([(2, 2)]))), hard=True),
    level(111, 'Zero G', 'full', [G('drop'), G('stains')], layout_fn=L('s', rect(0, 0, 1, 7)), gravity='up', buckets=4, every=4),
    level(112, 'Nebula', 'heart', [G('ink'), G('collect', 18, 'green')], colors=['red', 'blue', 'yellow', 'brown'],
          layout_fn=L('i', mirror2([(4, 1), (4, 2)])), filters=dict.fromkeys(mirror2([(1, 2)]), 'G')),
    level(113, 'Asteroid Belt', 'pillars', [G('glass'), G('locks')], layout_fn=chain(L('1', row_cells(3)), L('k', row_cells(5))),
          switch=0.05),
    level(114, 'Starlight', 'full', [G('score', 45000), G('drop')], buckets=4,
          zones={**{(r, 0): '>' for r in range(N)}, **{(r, 7): '<' for r in range(N)}}),
    level(115, 'Eclipse', 'frame', [G('ink'), G('locks'), G('glass')], colors=5,
          layout_fn=chain(L('i', mirror2([(3, 1)])), L('k', mirror4([(1, 3)])), L('1', mirror4([(2, 1)]))), every=5, hard=True),
    level(116, 'Gravity Well', 'full', [G('stains'), G('drop')], layout_fn=L('s', rect(5, 0, 7, 7)), buckets=4,
          zones={**{(r, 3): '^' for r in range(N)}, **{(r, 4): '^' for r in range(N)}}, switch=0.04),
    level(117, 'Constellation', 'frame', [G('locks'), G('collect', 18, 'orange')], colors=['red', 'blue', 'yellow', 'gray'],
          layout_fn=L('k', mirror4([(0, 0), (1, 3), (3, 1)])), filters=dict.fromkeys([(3, 2), (4, 5)], 'O')),
    level(118, 'Warp Drive', 'tall', [G('ink'), G('drop')], layout_fn=L('i', [(3, 3), (3, 4)]), gravity='left', buckets=4, every=3),
    level(119, 'Cosmic Canvas', 'full', [G('stains'), G('glass'), G('locks'), G('ink')], colors=5,
          layout_fn=chain(L('s', rect(0, 0, 1, 7)), L('1', mirror4([(3, 0)])), L('k', mirror4([(3, 3)])), L('i', [(7, 3), (7, 4)])),
          every=5),
    level(120, 'Blend Burst', 'full', [G('drop'), G('ink'), G('locks'), G('collect', 20, 'purple')], colors=6,
          layout_fn=chain(L('K', mirror4([(2, 2)])), L('i', [(4, 0), (4, 7)])), buckets=5,
          filters=dict.fromkeys(mirror2([(1, 2)]), 'P'), every=6, hard=True),
]

EPISODES = [
    ('episode4.json', 'Sky Gallery', sky),
    ('episode5.json', 'Ink Lagoon', lagoon),
    ('episode6.json', 'Prism Peaks', peaks),
    ('episode7.json', 'Bucket Brigade', brigade),
    ('episode8.json', 'Gravity Galaxy', galaxy),
]


def dump_level(l):
    """One field per line, as the bot's rewriter expects."""
    out = ['    {']
    keys = list(l.keys())
    for i, k in enumerate(keys):
        v = l[k]
        comma = ',' if i < len(keys) - 1 else ''
        if k in ('layout', 'tiles', 'filters', 'zones'):
            inner = ',\n'.join(f'        {json.dumps(r)}' for r in v)
            out.append(f'      "{k}": [\n{inner}\n      ]{comma}')
        else:
            out.append(f'      "{k}": {json.dumps(v)}{comma}')
    out.append('    }')
    return '\n'.join(out)


def keep_tuning(path, levels):
    """Copies tuned moves/stars from the existing pack for every level whose
    design did not change, so only edited levels need re-tuning."""
    if not os.path.exists(path):
        return
    with open(path) as f:
        old = {l['id']: l for l in json.load(f)['levels']}
    for l in levels:
        o = old.get(l['id'])
        if o is None:
            continue
        same = {k: v for k, v in o.items() if k not in ('moves', 'stars')} == \
            {k: v for k, v in l.items() if k not in ('moves', 'stars')}
        if same:
            l['moves'], l['stars'] = o['moves'], o['stars']
        else:
            print('changed:', l['id'], l['name'])


def write_pack(path, name, levels):
    keep_tuning(path, levels)
    body = ',\n'.join(dump_level(l) for l in levels)
    with open(path, 'w') as f:
        f.write('{\n  "episode": ' + json.dumps(name) + ',\n  "levels": [\n' + body + '\n  ]\n}\n')


def main():
    base = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels')
    ep3 = os.path.join(base, 'episode3.json')
    with open(ep3) as f:
        pack = json.load(f)
    keep = [l for l in pack['levels'] if l['id'] <= 40]
    # Keep the hand-made 31..40 exactly as they are; rewrite only 41..45.
    with open(ep3) as f:
        text = f.read()
    if any(l['id'] > 40 for l in pack['levels']):
        write_pack(ep3, pack['episode'], keep + factory)
    else:
        head = text.rstrip().rstrip('}').rstrip().rstrip(']').rstrip()
        extra = ',\n'.join(dump_level(l) for l in factory)
        with open(ep3, 'w') as f:
            f.write(head + ',\n' + extra + '\n  ]\n}\n')
    for fname, name, levels in EPISODES:
        write_pack(os.path.join(base, fname), name, levels)
    total = len(keep) + len(factory) + sum(len(e[2]) for e in EPISODES)
    print('levels 1..40 kept, wrote', total - len(keep), 'new levels')


if __name__ == '__main__':
    main()
