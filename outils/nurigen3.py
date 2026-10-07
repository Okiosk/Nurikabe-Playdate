"""Generateur v3 : unicite verifiee par clingo (ASP), iles de taille quelconque.

  python3 nurigen3.py levels  <graine> <sortie.lua> <index_niveau>
  python3 nurigen3.py mosaic  <graine> <sortie.lua> <nom_image> [apercu.png]
Les resultats sont ecrits au fur et a mesure (.partial) pour ne rien perdre.
"""
import json, os, random, subprocess, sys, time

from nurigen2 import Geo, islands_of, makes_pool, random_solution, sea_connected, encode

HERE = os.path.dirname(os.path.abspath(__file__))
CLINGO = os.environ.get('CLINGO') or (os.path.join(HERE, 'clingo-src', 'build', 'bin', 'clingo') if os.path.exists(os.path.join(HERE, 'clingo-src')) else 'clingo')
ENCODING = os.path.join(HERE, 'nurikabe.lp')

DIGITS = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'


def asp_solve(n, clues, models=2, time_limit=20):
    """clues : dict index -> taille. Renvoie (nb_modeles plafonne, [masques_blancs], conflits) ou (None,..)."""
    facts = '#const n=%d.\n' % n + ''.join('clue(%d,%d,%d).\n' % (i // n + 1, i % n + 1, v) for i, v in clues.items())
    try:
        p = subprocess.run([CLINGO, ENCODING, '-', '--models=%d' % models, '--outf=2', '--stats',
                            '--time-limit=%d' % time_limit],
                           input=facts, capture_output=True, text=True, timeout=time_limit + 10)
    except subprocess.TimeoutExpired:
        return None, None, None
    data = json.loads(p.stdout)
    if data.get('Result') == 'UNKNOWN' or data.get('Time', {}).get('Total', 0) >= time_limit:
        if data['Models']['Number'] < models:
            return None, None, None
    full = (1 << (n * n)) - 1
    sols = []
    for w in data['Call'][0].get('Witnesses', []):
        black = 0
        for atom in w['Value']:
            r, c = atom[6:-1].split(',')
            black |= 1 << ((int(r) - 1) * n + int(c) - 1)
        sols.append(full & ~black)
    core = data.get('Stats', {}).get('Core', {})
    conflicts = core.get('Conflicts', 0) + core.get('Choices', 0)
    return data['Models']['Number'], sols, conflicts


def white_mask(g, black):
    m = 0
    for i in range(g.N):
        if not black[i]:
            m |= 1 << i
    return m


def make_unique(g, black, max_island, tries=2, iters=40, time_limit=20, allow_new_ones=True):
    """Place un indice par ile puis repare jusqu'a l'unicite (voir nurigen2.place_and_check)."""
    for _ in range(tries):
        blk = list(black)
        comps = islands_of(g, blk)
        clues = {random.choice(comp): len(comp) for comp in comps}
        for _ in range(iters):
            cnt, sols, conf = asp_solve(g.n, clues, 2, time_limit)
            if cnt is None or cnt == 0:
                break
            ours = white_mask(g, blk)
            if cnt == 1:
                if sols[0] != ours:
                    raise AssertionError((blk, dict(clues), sols[0]))
                return blk, clues, conf
            alt = sols[0] if sols[0] != ours else sols[1]
            comps = islands_of(g, blk)
            owner = {}
            for k, comp in enumerate(comps):
                for x in comp:
                    owner[x] = k
            clue_of = {owner[c]: c for c in clues}
            done = False
            if random.random() < 0.5:
                cells = [i for i in range(g.N) if (alt & ~ours) >> i & 1]
                random.shuffle(cells)
                for x in cells:
                    adj = set(owner[j] for j in g.nb[x] if not blk[j])
                    if len(adj) > 1 or (not adj and not allow_new_ones):
                        continue
                    blk[x] = False
                    if not sea_connected(g, blk) or not any(blk):
                        blk[x] = True
                        continue
                    if adj:
                        k = adj.pop()
                        if len(comps[k]) + 1 > max_island:
                            blk[x] = True
                            continue
                        clues[clue_of[k]] += 1
                    else:
                        clues[x] = 1
                    done = True
                    break
            if not done:
                cells = [i for i in range(g.N) if (ours & ~alt) >> i & 1]
                random.shuffle(cells)
                for x in cells:
                    c = clue_of[owner[x]]
                    clues[x] = clues.pop(c)
                    done = True
                    break
            if not done:
                break
    return None


def encode36(n, black, clues):
    grid, sol = [], []
    for r in range(n):
        row, srow = '', ''
        for c in range(n):
            i = r * n + c
            row += DIGITS[clues[i]] if i in clues else '.'
            srow += '#' if black[i] else '.'
        grid.append(row)
        sol.append(srow)
    return grid, sol


def lua_entry(grid, sol, indent='\t\t'):
    return (indent + '{ grid = {%s},\n' % ', '.join('"%s"' % x for x in grid)
            + indent + '  sol = {%s} },' % ', '.join('"%s"' % x for x in sol))

# ------------------------------------------------------------------ niveaux

LEVELS = [
    # taille, nom, nb, ile max, ratio noir, iles min, part max de "1", candidats gardes
    (7, "Facile", 12, 9, 0.52, 6, 0.35, 3),
    (8, "Moyen", 12, 10, 0.53, 7, 0.35, 4),
    (10, "Difficile", 12, 12, 0.55, 9, 0.35, 4),
    (12, "Expert", 12, 14, 0.55, 12, 0.35, 4),
]


def gen_level(seed, out_path, li):
    random.seed(seed)
    n, name, count, mx, ratio, minc, ones, pool = LEVELS[li]
    g = Geo(n)
    found = []
    seen = set()
    t0 = time.time()
    while len(found) < count:
        batch = []
        attempts = 0
        while len(batch) < pool and attempts < 300:
            attempts += 1
            black = random_solution(g, mx, ratio)
            if black is None:
                continue
            comps = islands_of(g, black)
            if len(comps) < minc or sum(1 for c in comps if len(c) == 1) / len(comps) > ones:
                continue
            res = make_unique(g, black, mx, 2, 30, 20, allow_new_ones=False)
            if res:
                blk, clues, conf = res
                grid, sol = encode36(n, blk, clues)
                if tuple(grid) not in seen:
                    batch.append((conf, grid, sol))
        if not batch:
            continue
        batch.sort(key=lambda x: -x[0])
        conf, grid, sol = batch[0]
        seen.add(tuple(grid))
        found.append((conf, grid, sol))
        print(f"{name} {n}x{n} #{len(found)} conflits={conf} ({time.time()-t0:.0f}s)", file=sys.stderr, flush=True)
        with open(out_path + '.partial', 'a') as f:
            f.write(json.dumps([conf, grid, sol]) + '\n')
    found.sort(key=lambda x: x[0])
    lines = ['\t{ size = %d, name = "%s", list = {' % (n, name)]
    for conf, grid, sol in found:
        lines.append(lua_entry(grid, sol))
    lines.append('\t} },')
    with open(out_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')

# ------------------------------------------------------------------ mosaiques

TILE = 8


def improve_towards(g, black, target, max_island, rounds=8):
    N = g.N
    for _ in range(rounds):
        changed = False
        order = list(range(N))
        random.shuffle(order)
        for i in order:
            want_black = bool(target[i])
            if black[i] == want_black:
                continue
            if want_black:
                if makes_pool(g, black, i) or not any(black[j] for j in g.nb[i]):
                    continue
                black[i] = True
                changed = True
            else:
                black[i] = False
                ok = any(black) and sea_connected(g, black)
                if ok:
                    comp, seen, k = [i], {i}, 0
                    while k < len(comp) and len(comp) <= max_island:
                        for j in g.nb[comp[k]]:
                            if not black[j] and j not in seen:
                                seen.add(j)
                                comp.append(j)
                        k += 1
                    ok = len(comp) <= max_island
                if ok:
                    changed = True
                else:
                    black[i] = True
        if not changed:
            break
    return black


def tile_solution(g, target, max_island):
    """Solution valide proche de l'image : mer = zones sombres (trouees pour eviter les 2x2),
    zones claires = grandes iles, reliees par des chemins de mer minimaux."""
    N, n = g.N, g.n
    dark = [i for i in range(N) if target[i]]
    black = [False] * N
    black[random.choice(dark) if dark else random.randrange(N)] = True
    while True:
        frontier = [i for i in range(N) if not black[i] and any(black[j] for j in g.nb[i])
                    and not makes_pool(g, black, i)]
        if not frontier:
            break
        comps = islands_of(g, black)
        big = [c for c in comps if len(c) > max_island]
        darkf = [i for i in frontier if target[i]]
        if darkf or big:
            bigset = set(x for c in big for x in c)
            weights = [(20 if target[i] else 1) * (8 if i in bigset else 1) for i in frontier]
            black[random.choices(frontier, weights)[0]] = True
            continue
        fset = set(frontier)
        unreached = [i for i in dark if not black[i] and i not in fset and not makes_pool(g, black, i)]
        if not unreached:
            break
        def dist(i):
            r, c = divmod(i, n)
            return min(abs(r - u // n) + abs(c - u % n) for u in unreached)
        best = min(dist(i) for i in frontier)
        black[random.choice([i for i in frontier if dist(i) == best])] = True
    comps = islands_of(g, black)
    if not comps or any(len(c) > max_island for c in comps):
        return None
    return improve_towards(g, black, target, max_island)


def gen_tile(target, max_island, candidates=40, want=2):
    g = Geo(TILE)
    cands = []
    for _ in range(candidates * 3):
        black = tile_solution(g, target, max_island)
        if black is None or not sea_connected(g, black):
            continue
        if any(len(c) > max_island for c in islands_of(g, black)):
            continue
        score = sum(1 for i in range(g.N) if black[i] == bool(target[i]))
        cands.append((score, black))
        if len(cands) >= candidates:
            break
    cands.sort(key=lambda x: -x[0])
    found = []
    for score, black in cands[:15]:
        res = make_unique(g, black, max_island, 2, 25, 10)
        if res:
            blk, clues, _ = res
            s2 = sum(1 for i in range(g.N) if blk[i] == bool(target[i]))
            found.append((s2, blk, clues))
            if len(found) >= want:
                break
    if not found:
        return None
    found.sort(key=lambda x: -x[0])
    return found[0][1], found[0][2], found[0][0]


def gen_mosaic(seed, out_path, image_name, preview=None, max_island=61):
    from mosaic_images import IMAGES
    random.seed(seed)
    art = dict(IMAGES)[image_name]
    h, w = len(art), len(art[0])
    rows, cols = h // TILE, w // TILE
    lines = ['\t{ name = "%s", cols = %d, rows = %d,' % (image_name, cols, rows),
             '\t  image = {%s},' % ', '.join('"%s"' % r for r in art),
             '\t  tiles = {']
    assembled = [['.'] * w for _ in range(h)]
    total = 0
    for tr in range(rows):
        for tc in range(cols):
            target = [1 if art[tr * TILE + r][tc * TILE + c] == '#' else 0 for r in range(TILE) for c in range(TILE)]
            res = None
            attempt = 0
            while res is None:
                # repli : si la piece resiste, on autorise moins de grandes iles (plus de mer)
                caps = [max_island] * 4 + [40, 25, 16, 10, 8]
                res = gen_tile(target, caps[min(attempt, len(caps) - 1)])
                attempt += 1
            blk, clues, score = res
            total += score
            grid, sol = encode36(TILE, blk, clues)
            for r in range(TILE):
                for c in range(TILE):
                    assembled[tr * TILE + r][tc * TILE + c] = sol[r][c]
            lines.append(lua_entry(grid, sol, '\t\t'))
            print(f"{image_name} {tr},{tc} accord={score}/64", file=sys.stderr, flush=True)
    lines.append('\t} },')
    with open(out_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f"{image_name}: accord {total / (rows * cols * 64):.0%}", file=sys.stderr, flush=True)
    if preview:
        from PIL import Image
        S = 6
        im = Image.new('L', (w * S * 2 + 30, h * S + 20), 180)
        for grid, off in ((art, 10), (assembled, w * S + 20)):
            for r, row in enumerate(grid):
                for c, ch in enumerate(row):
                    im.paste(0 if ch == '#' else 255, (off + c * S, 10 + r * S, off + c * S + S, 10 + r * S + S))
        im.save(preview)


if __name__ == '__main__':
    if sys.argv[1] == 'levels':
        gen_level(int(sys.argv[2]), sys.argv[3], int(sys.argv[4]))
    else:
        gen_mosaic(int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else None)
