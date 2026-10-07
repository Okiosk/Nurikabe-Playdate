"""Generateur de grilles Nurikabe (solution unique verifiee).

  python3 nurigen.py levels  <graine> <sortie.lua>
  python3 nurigen.py mosaics <graine> <sortie.lua> [apercu.png]
"""
import random, sys, time

# ------------------------------------------------------------------ outils bitmask

class Geo:
    def __init__(self, n):
        self.n = n
        self.N = n * n
        self.full = (1 << self.N) - 1
        left = 0
        right = 0
        for r in range(n):
            left |= 1 << (r * n)
            right |= 1 << (r * n + n - 1)
        self.notLeft = self.full & ~left    # cases qui ne sont pas en colonne 0
        self.notRight = self.full & ~right
        self.nb = [list(self._nb(i)) for i in range(self.N)]
        self.blocks = []
        for r in range(n - 1):
            for c in range(n - 1):
                i = r * n + c
                self.blocks.append((1 << i) | (1 << (i + 1)) | (1 << (i + n)) | (1 << (i + n + 1)))

    def _nb(self, i):
        n = self.n
        r, c = divmod(i, n)
        if r > 0: yield i - n
        if r < n - 1: yield i + n
        if c > 0: yield i - 1
        if c < n - 1: yield i + 1

    def grow(self, m):
        return (m | ((m << 1) & self.notLeft) | ((m >> 1) & self.notRight)
                | (m << self.n) | (m >> self.n)) & self.full

    def flood(self, seed, region):
        cur = seed & region
        while True:
            nxt = self.grow(cur) & region
            if nxt == cur:
                return cur
            cur = nxt

    def connected(self, mask):
        if mask == 0:
            return True
        return self.flood(mask & -mask, mask) == mask


_SHAPE_CACHE = {}


def shapes_for_clue(g, cell, size, forbidden, cap=120000):
    key = (g.n, cell, size, forbidden)
    if key in _SHAPE_CACHE:
        return _SHAPE_CACHE[key]
    res = _shapes_for_clue(g, cell, size, forbidden, cap)
    if len(_SHAPE_CACHE) > 20000:
        _SHAPE_CACHE.clear()
    _SHAPE_CACHE[key] = res
    return res


def _shapes_for_clue(g, cell, size, forbidden, cap=120000):
    """Polyominos de taille `size` contenant `cell`, sans toucher les autres indices."""
    nb = g.nb
    bad = 0  # cases interdites : autres indices et leurs voisins
    for i in range(g.N):
        if forbidden >> i & 1:
            bad |= 1 << i
            for j in nb[i]:
                bad |= 1 << j
    bad &= ~(1 << cell)
    frontier = {1 << cell}
    for _ in range(size - 1):
        nxt = set()
        for m in frontier:
            border = g.grow(m) & ~m & ~bad
            while border:
                low = border & -border
                nxt.add(m | low)
                border ^= low
        frontier = nxt
        if len(frontier) > cap:
            return None
    return [(m, g.grow(m) & ~m) for m in frontier]


def count_solutions(n, clues, limit=2, node_limit=300000):
    """Renvoie (nb_solutions plafonne, solution_blanche, noeuds) ou (None, None, None)."""
    g = Geo(n)
    clue_mask = 0
    for c in clues:
        clue_mask |= 1 << c
    cands = {}
    for c, s in clues.items():
        sh = shapes_for_clue(g, c, s, clue_mask & ~(1 << c))
        if sh is None:
            return None, None, None
        cands[c] = sh
    blocks = g.blocks
    sols = []
    nodes = [0]

    def rec(filtered, white, blocked):
        nodes[0] += 1
        if nodes[0] > node_limit:
            raise TimeoutError
        if not filtered:
            black = g.full & ~white
            for b in blocks:
                if black & b == b:
                    return
            if g.connected(black):
                sols.append(white)
            return
        cover = white
        best = None
        for c, lst in filtered.items():
            if not lst:
                return
            for m, _ in lst:
                cover |= m
            if best is None or len(lst) < len(filtered[best]):
                best = c
        for b in blocks:
            if not (cover & b):
                return
        # cases forcement noires : doivent pouvoir se rejoindre hors des iles posees
        sure_black = g.full & ~cover
        if sure_black:
            region = g.full & ~white
            if g.flood(sure_black & -sure_black, region) & sure_black != sure_black:
                return
        for m, h in filtered[best]:
            nb_ = blocked | m | h
            nf = {}
            ok = True
            for c, lst in filtered.items():
                if c == best:
                    continue
                l2 = [x for x in lst if not (x[0] & nb_)]
                if not l2:
                    ok = False
                    break
                nf[c] = l2
            if ok:
                rec(nf, white | m, nb_)
            if len(sols) >= limit:
                return

    try:
        rec({c: list(v) for c, v in cands.items()}, 0, 0)
    except TimeoutError:
        return None, None, None
    return len(sols), sols, nodes[0]

# ------------------------------------------------------------------ solutions aleatoires

def islands_of(g, black):
    seen = [False] * g.N
    comps = []
    for i in range(g.N):
        if not black[i] and not seen[i]:
            comp = [i]
            seen[i] = True
            k = 0
            while k < len(comp):
                for j in g.nb[comp[k]]:
                    if not black[j] and not seen[j]:
                        seen[j] = True
                        comp.append(j)
                k += 1
            comps.append(comp)
    return comps


def makes_pool(g, black, i):
    n = g.n
    r, c = divmod(i, n)
    for dr in (-1, 0):
        for dc in (-1, 0):
            rr, cc = r + dr, c + dc
            if 0 <= rr < n - 1 and 0 <= cc < n - 1:
                k = rr * n + cc
                if all(black[x] or x == i for x in (k, k + 1, k + n, k + n + 1)):
                    return True
    return False


def random_solution(g, max_island, black_ratio, target=None):
    """Mer connexe sans 2x2. Si `target` (liste 0/1, 1 = sombre) est fourni,
    la croissance privilegie les cases sombres."""
    N = g.N
    black = [False] * N
    if target:
        dark = [i for i in range(N) if target[i]]
        start = random.choice(dark) if dark else random.randrange(N)
    else:
        start = random.randrange(N)
    black[start] = True
    nblack = 1
    goal = int(N * black_ratio)
    while True:
        frontier = [i for i in range(N) if not black[i]
                    and any(black[j] for j in g.nb[i]) and not makes_pool(g, black, i)]
        if not frontier:
            break
        comps = islands_of(g, black)
        big = [c for c in comps if len(c) > max_island]
        if target:
            darkf = [i for i in frontier if target[i]]
            if not darkf and not big:
                break
            weights = [12 if target[i] else 1 for i in frontier]
            if big:
                bigset = set(x for c in big for x in c)
                weights = [w * (6 if i in bigset else 1) for i, w in zip(frontier, weights)]
            i = random.choices(frontier, weights)[0]
        else:
            if nblack >= goal and not big:
                break
            if big and random.random() < 0.7:
                bigset = set(x for c in big for x in c)
                pref = [i for i in frontier if i in bigset]
                if pref:
                    frontier = pref
            i = random.choice(frontier)
        black[i] = True
        nblack += 1
    comps = islands_of(g, black)
    if not comps or any(len(c) > max_island for c in comps):
        return None
    return black


def sea_connected(g, black):
    mask = 0
    for i in range(g.N):
        if black[i]:
            mask |= 1 << i
    return g.connected(mask)


def improve_towards(g, black, target, max_island, rounds=6):
    """Escalade : retourne les cases en desaccord avec l'image tant que les regles tiennent."""
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
                # l'ile coupee doit garder des morceaux non vides : toujours vrai
                changed = True
            else:
                black[i] = False
                ok = sea_connected(g, black) and any(black)
                if ok:
                    # taille de l'ile fusionnee
                    comp = [i]
                    seen = {i}
                    k = 0
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


def white_mask(g, black):
    m = 0
    for i in range(g.N):
        if not black[i]:
            m |= 1 << i
    return m


def place_and_check(g, black, tries=3, node_limit=300000, max_ones_ratio=1.0, max_island=9, iters=30):
    """Place un indice par ile puis repare jusqu'a l'unicite. Reparations possibles :
    - deplacer un indice sur une case blanche chez nous mais noire dans l'autre solution ;
    - agrandir une ile sur une case noire chez nous mais blanche dans l'autre ;
    - creer une ile de 1 sur une telle case.
    Renvoie (black, clues, noeuds) ou None. `black` peut avoir ete modifie."""
    comps0 = islands_of(g, black)
    ones = sum(1 for c in comps0 if len(c) == 1)
    if comps0 and ones / len(comps0) > max_ones_ratio:
        return None
    for _ in range(tries):
        blk = list(black)
        comps = islands_of(g, blk)
        clues = {random.choice(comp): len(comp) for comp in comps}
        for it in range(iters):
            cnt, sols, nodes = count_solutions(g.n, clues, 2, node_limit)
            if cnt is None or cnt == 0:
                break
            if cnt == 1:
                return blk, clues, nodes
            ours = white_mask(g, blk)
            alt = sols[0] if sols[0] != ours else sols[1]
            comps = islands_of(g, blk)
            owner = {}
            for k, comp in enumerate(comps):
                for x in comp:
                    owner[x] = k
            clue_of = {owner[c]: c for c in clues}
            done = False
            if random.random() < 0.5:
                # reparation structurelle
                cells = [i for i in range(g.N) if (alt & ~ours) >> i & 1]
                random.shuffle(cells)
                for x in cells:
                    adj = set(owner[j] for j in g.nb[x] if not blk[j])
                    if len(adj) > 1:
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
                    k = owner[x]
                    c = clue_of[k]
                    clues[x] = clues.pop(c)
                    done = True
                    break
            if not done:
                break
    return None


def encode(n, black, clues):
    grid, sol = [], []
    for r in range(n):
        row, srow = '', ''
        for c in range(n):
            i = r * n + c
            row += str(clues[i]) if i in clues else '.'
            srow += '#' if black[i] else '.'
        grid.append(row)
        sol.append(srow)
    return grid, sol

# ------------------------------------------------------------------ mode niveaux

LEVELS = [
    # taille, nom, nb, ile max, ratio noir, indices min, part max de "1", candidats par grille
    (7, "Facile", 12, 7, 0.55, 6, 0.40, 4),
    (8, "Moyen", 12, 8, 0.57, 7, 0.45, 5),
    (10, "Difficile", 12, 8, 0.58, 10, 0.45, 4),
    (12, "Expert", 12, 8, 0.58, 14, 0.50, 3),
]


def gen_levels(seed, out_path, only=None):
    random.seed(seed)
    out = ["-- Grilles generees (solution unique verifiee). Ne pas modifier a la main.",
           "PUZZLES = {"]
    for li, (n, name, count, mx, ratio, minc, ones, pool) in enumerate(LEVELS):
        if only is not None and li != only:
            continue
        g = Geo(n)
        out.append('\t{ size = %d, name = "%s", list = {' % (n, name))
        found = []
        seen = set()
        t0 = time.time()
        while len(found) < count:
            # on garde la plus "difficile" (plus de noeuds de recherche) parmi `pool` grilles valides
            batch = []
            attempts = 0
            while len(batch) < pool and attempts < 400:
                attempts += 1
                black = random_solution(g, mx, ratio)
                if black is None or len(islands_of(g, black)) < minc:
                    continue
                res = place_and_check(g, black, 2, 40000, ones, mx)
                if res:
                    black, clues, nodes = res
                    grid, sol = encode(n, black, clues)
                    if tuple(grid) not in seen:
                        batch.append((nodes, grid, sol))
            if not batch:
                continue
            batch.sort(key=lambda x: -x[0])
            nodes, grid, sol = batch[0]
            seen.add(tuple(grid))
            found.append((nodes, grid, sol))
            print(f"{name} {n}x{n} #{len(found)} noeuds={nodes} ({time.time()-t0:.0f}s)", file=sys.stderr, flush=True)
        # tri du plus facile au plus dur
        found.sort(key=lambda x: x[0])
        for nodes, grid, sol in found:
            out.append('\t\t{ grid = {%s},' % ', '.join('"%s"' % x for x in grid))
            out.append('\t\t  sol = {%s} },' % ', '.join('"%s"' % x for x in sol))
        out.append('\t} },')
    out.append('}')
    with open(out_path, 'w') as f:
        f.write('\n'.join(out) + '\n')

# ------------------------------------------------------------------ mode mosaique

TILE = 8


def gen_tile(target, max_island=6, candidates=60, iters=15, want=4):
    """Cherche plusieurs pieces uniques et garde celle qui ressemble le plus a l'image."""
    g = Geo(TILE)
    cands = []
    for _ in range(candidates * 4):
        black = random_solution(g, max_island, 0.5, target)
        if black is None:
            continue
        black = improve_towards(g, black, target, max_island)
        if not sea_connected(g, black) or any(len(c) > max_island for c in islands_of(g, black)):
            continue
        score = sum(1 for i in range(g.N) if black[i] == bool(target[i]))
        cands.append((score, black))
        if len(cands) >= candidates:
            break
    cands.sort(key=lambda x: -x[0])
    found = []
    for score, black in cands:
        res = place_and_check(g, black, 2, 40000, 1.0, max_island, iters)
        if res:
            black2, clues, _ = res
            score2 = sum(1 for i in range(g.N) if black2[i] == bool(target[i]))
            found.append((score2, black2, clues))
            if len(found) >= want:
                break
    if not found:
        return None
    found.sort(key=lambda x: -x[0])
    score, black, clues = found[0]
    return black, clues, score


def gen_mosaics(seed, out_path, preview=None):
    from mosaic_images import IMAGES
    random.seed(seed)
    out = ["-- Mosaiques : chaque piece est un Nurikabe ; les solutions assemblees forment l'image.",
           "MOSAICS = {"]
    previews = []
    for name, art in IMAGES:
        h = len(art)
        w = len(art[0])
        assert h % TILE == 0 and w % TILE == 0 and all(len(r) == w for r in art), name
        rows, cols = h // TILE, w // TILE
        out.append('\t{ name = "%s", cols = %d, rows = %d,' % (name, cols, rows))
        out.append('\t  image = {%s},' % ', '.join('"%s"' % r for r in art))
        out.append('\t  tiles = {')
        assembled = [['.'] * w for _ in range(h)]
        total_score = 0
        for tr in range(rows):
            for tc in range(cols):
                target = [1 if art[tr * TILE + r][tc * TILE + c] == '#' else 0
                          for r in range(TILE) for c in range(TILE)]
                res = None
                while res is None:
                    res = gen_tile(target)
                black, clues, score = res
                total_score += score
                grid, sol = encode(TILE, black, clues)
                for r in range(TILE):
                    for c in range(TILE):
                        assembled[tr * TILE + r][tc * TILE + c] = sol[r][c]
                out.append('\t\t{ grid = {%s},' % ', '.join('"%s"' % x for x in grid))
                out.append('\t\t  sol = {%s} },' % ', '.join('"%s"' % x for x in sol))
                print(f"{name} piece {tr},{tc} accord={score}/64", file=sys.stderr, flush=True)
        out.append('\t} },')
        previews.append((name, art, assembled))
        print(f"{name}: accord moyen {total_score / (rows * cols * 64):.0%}", file=sys.stderr)
    out.append('}')
    with open(out_path, 'w') as f:
        f.write('\n'.join(out) + '\n')
    if preview:
        from PIL import Image
        s = 6
        W = sum(len(a[0]) * 2 * s + 30 for _, a, _ in previews)
        H = max(len(a) for _, a, _ in previews) * s + 20
        img = Image.new('L', (W, H), 200)
        x0 = 10
        for name, art, asm in previews:
            for grid, off in ((art, 0), (asm, len(art[0]) * s + 6)):
                for r, row in enumerate(grid):
                    for c, ch in enumerate(row):
                        col = 0 if ch == '#' else 255
                        for dy in range(s):
                            for dx in range(s):
                                img.putpixel((x0 + off + c * s + dx, 10 + r * s + dy), col)
            x0 += len(art[0]) * 2 * s + 30
        img.save(preview)


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'levels':
        only = int(sys.argv[4]) if len(sys.argv) > 4 else None
        gen_levels(int(sys.argv[2]), sys.argv[3], only)
    else:
        gen_mosaics(int(sys.argv[2]), sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
