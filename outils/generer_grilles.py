"""Generateur de grilles Nurikabe a solution unique.
Sortie : puzzles.lua (table globale PUZZLES).
"""
import random, sys, time

def neighbors(n, i):
    r, c = divmod(i, n)
    if r > 0: yield i - n
    if r < n - 1: yield i + n
    if c > 0: yield i - 1
    if c < n - 1: yield i + 1

def blocks2x2(n):
    out = []
    for r in range(n - 1):
        for c in range(n - 1):
            i = r * n + c
            out.append((1 << i) | (1 << (i + 1)) | (1 << (i + n)) | (1 << (i + n + 1)))
    return out

def connected(n, mask):
    """mask = ensemble de cases ; True si 4-connexe (ou vide)."""
    if mask == 0:
        return True
    start = (mask & -mask).bit_length() - 1
    seen = 1 << start
    stack = [start]
    while stack:
        i = stack.pop()
        for j in neighbors(n, i):
            b = 1 << j
            if mask & b and not seen & b:
                seen |= b
                stack.append(j)
    return seen == mask

def shapes_for_clue(n, cell, size, forbidden):
    """Tous les polyominos de taille `size` contenant `cell`, sans case de `forbidden`
    et sans voisin dans `forbidden` (les autres indices)."""
    nb = [[j for j in neighbors(n, i)] for i in range(n * n)]
    results = set()
    start = 1 << cell
    # enumeration par extension (ensemble de formes deja vues pour eviter les doublons)
    frontier = {start}
    for _ in range(size - 1):
        nxt = set()
        for m in frontier:
            # cases adjacentes
            cells = [i for i in range(n * n) if m >> i & 1]
            for i in cells:
                for j in nb[i]:
                    b = 1 << j
                    if m & b or forbidden & b:
                        continue
                    # j ne doit pas toucher un autre indice
                    if any(forbidden >> k & 1 for k in nb[j]):
                        continue
                    nxt.add(m | b)
        frontier = nxt
        if len(frontier) > 60000:
            return None
    for m in frontier:
        halo = 0
        x = m
        while x:
            low = x & -x
            i = low.bit_length() - 1
            for j in nb[i]:
                halo |= 1 << j
            x ^= low
        halo &= ~m
        results.add((m, halo))
    return list(results)

def count_solutions(n, clues, limit=2, node_limit=200000):
    """clues: dict cell->size. Renvoie (nb_solutions (cap limit), solution_mask_blanc) ou (None, None) si trop long."""
    full = (1 << (n * n)) - 1
    clue_mask = 0
    for c in clues:
        clue_mask |= 1 << c
    cands = {}
    for c, s in clues.items():
        forb = clue_mask & ~(1 << c)
        sh = shapes_for_clue(n, c, s, forb)
        if sh is None:
            return None, None
        cands[c] = sh
    blocks = blocks2x2(n)
    total_white = sum(clues.values())
    sols = []
    nodes = [0]

    def rec(remaining, white, blocked):
        nodes[0] += 1
        if nodes[0] > node_limit:
            raise TimeoutError
        if not remaining:
            black = full & ~white
            for b in blocks:
                if black & b == b:
                    return
            if connected(n, black):
                sols.append(white)
            return
        # filtre des candidats compatibles + MRV
        best = None
        cover = white
        filtered = {}
        for c in remaining:
            lst = [(m, h) for (m, h) in cands[c] if not (m & blocked)]
            if not lst:
                return
            filtered[c] = lst
            for m, _ in lst:
                cover |= m
            if best is None or len(lst) < len(filtered[best]):
                best = c
        # elagage 2x2 : un bloc qui ne pourra jamais contenir de blanc
        for b in blocks:
            if not (cover & b):
                return
        rest = [c for c in remaining if c != best]
        for m, h in filtered[best]:
            rec(rest, white | m, blocked | m | h)
            if len(sols) >= limit:
                return

    try:
        rec(list(clues.keys()), 0, 0)
    except TimeoutError:
        return None, None
    return len(sols), (sols[0] if sols else None)

def random_solution(n, max_island, black_ratio):
    """Construit une mer connexe sans bloc 2x2, les composantes blanches = iles."""
    N = n * n
    black = [False] * N
    start = random.randrange(N)
    black[start] = True
    nblack = 1
    target = int(N * black_ratio)

    def makes_pool(i):
        r, c = divmod(i, n)
        for dr in (-1, 0):
            for dc in (-1, 0):
                rr, cc = r + dr, c + dc
                if 0 <= rr < n - 1 and 0 <= cc < n - 1:
                    cells = [rr * n + cc, rr * n + cc + 1, (rr + 1) * n + cc, (rr + 1) * n + cc + 1]
                    if all(black[k] or k == i for k in cells):
                        return True
        return False

    def islands():
        seen = [False] * N
        comps = []
        for i in range(N):
            if not black[i] and not seen[i]:
                comp = [i]
                seen[i] = True
                k = 0
                while k < len(comp):
                    for j in neighbors(n, comp[k]):
                        if not black[j] and not seen[j]:
                            seen[j] = True
                            comp.append(j)
                    k += 1
                comps.append(comp)
        return comps

    stuck = 0
    while True:
        frontier = [i for i in range(N) if not black[i] and any(black[j] for j in neighbors(n, i)) and not makes_pool(i)]
        if not frontier:
            break
        comps = islands()
        big = [c for c in comps if len(c) > max_island]
        if nblack >= target and not big:
            break
        # priorite aux cases des grandes iles
        if big and random.random() < 0.7:
            bigset = set(x for c in big for x in c)
            pref = [i for i in frontier if i in bigset]
            if pref:
                frontier = pref
        i = random.choice(frontier)
        black[i] = True
        nblack += 1
    comps = islands()
    if any(len(c) > max_island for c in comps):
        return None
    if not comps:
        return None
    return black, comps

def make_puzzle(n, max_island, black_ratio, min_clues, tries=4000, node_limit=200000):
    for t in range(tries):
        res = random_solution(n, max_island, black_ratio)
        if res is None:
            continue
        black, comps = res
        if len(comps) < min_clues:
            continue
        # plusieurs essais de placement des indices dans la meme solution
        for _ in range(6):
            clues = {}
            for comp in comps:
                clues[random.choice(comp)] = len(comp)
            cnt, sol = count_solutions(n, clues, 2, node_limit)
            if cnt == 1:
                return black, clues
    return None

def encode(n, black, clues):
    grid = []
    sol = []
    for r in range(n):
        row = ''
        srow = ''
        for c in range(n):
            i = r * n + c
            row += str(clues[i]) if i in clues else '.'
            srow += '#' if black[i] else '.'
        grid.append(row)
        sol.append(srow)
    return grid, sol

LEVELS = [
    # (taille, nom, nb grilles, ile max, ratio noir, indices min)
    (5, "Facile", 12, 5, 0.56, 4),
    (7, "Moyen", 12, 7, 0.58, 7),
    (9, "Difficile", 12, 8, 0.60, 10),
]

def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 2026
    random.seed(seed)
    out = ["-- Grilles generees automatiquement (solution unique verifiee).",
           "-- '.' = case vide, chiffre = indice ; sol : '#' = noir, '.' = blanc.",
           "PUZZLES = {"]
    for n, name, count, mx, ratio, minc in LEVELS:
        out.append('\t{ size = %d, name = "%s", list = {' % (n, name))
        seen = set()
        made = 0
        t0 = time.time()
        while made < count:
            res = make_puzzle(n, mx, ratio, minc)
            if res is None:
                continue
            black, clues = res
            grid, sol = encode(n, black, clues)
            key = tuple(grid)
            if key in seen:
                continue
            seen.add(key)
            made += 1
            out.append('\t\t{ grid = {%s},' % ', '.join('"%s"' % g for g in grid))
            out.append('\t\t  sol = {%s} },' % ', '.join('"%s"' % s for s in sol))
            print(f"{n}x{n} #{made} ({time.time()-t0:.1f}s)", file=sys.stderr)
        out.append('\t} },')
    out.append('}')
    with open(sys.argv[2] if len(sys.argv) > 2 else 'puzzles.lua', 'w') as f:
        f.write('\n'.join(out) + '\n')

if __name__ == '__main__':
    main()
