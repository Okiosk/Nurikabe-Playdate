"""Images cibles des mosaiques ('#' = sombre). Dimensions multiples de 8."""
from PIL import Image, ImageDraw


def render(w, h, draw_fn):
    img = Image.new('1', (w, h), 0)
    d = ImageDraw.Draw(img)
    draw_fn(d)
    return [''.join('#' if img.getpixel((x, y)) else '.' for x in range(w)) for y in range(h)]


def coeur(d):
    d.ellipse([1, 1, 8, 8], fill=1)
    d.ellipse([7, 1, 14, 8], fill=1)
    d.polygon([(1, 6), (14, 6), (8, 14), (7, 14)], fill=1)


def poisson(d):
    d.ellipse([2, 3, 18, 12], fill=1)          # corps
    d.polygon([(16, 7), (23, 2), (23, 13)], fill=1)  # queue
    d.polygon([(8, 3), (12, 0), (13, 4)], fill=1)    # nageoire
    d.ellipse([5, 5, 7, 7], fill=0)            # oeil


def chat(d):
    d.ellipse([2, 6, 21, 23], fill=1)           # tete
    d.polygon([(3, 10), (4, 0), (11, 7)], fill=1)    # oreille gauche
    d.polygon([(20, 10), (19, 0), (12, 7)], fill=1)  # oreille droite
    d.ellipse([6, 11, 9, 15], fill=0)           # yeux
    d.ellipse([14, 11, 17, 15], fill=0)
    d.polygon([(10, 17), (13, 17), (11, 19), (12, 19)], fill=0)  # nez


def fusee(d):
    d.polygon([(8, 0), (12, 6), (4, 6)], fill=1)     # pointe
    d.rectangle([4, 6, 11, 17], fill=1)              # corps
    d.ellipse([6, 8, 9, 11], fill=0)                 # hublot
    d.polygon([(4, 12), (0, 19), (4, 18)], fill=1)   # ailerons
    d.polygon([(11, 12), (15, 19), (11, 18)], fill=1)
    d.polygon([(5, 18), (10, 18), (8, 23), (7, 23)], fill=1)  # flamme


def console(d):
    d.rounded_rectangle([1, 1, 20, 22], radius=3, fill=1)   # boitier
    d.rectangle([4, 4, 17, 12], fill=0)                      # ecran
    d.ellipse([4, 15, 8, 19], fill=0)                        # croix (rond)
    d.ellipse([12, 16, 14, 18], fill=0)                      # boutons
    d.ellipse([15, 15, 17, 17], fill=0)
    d.rectangle([21, 10, 21, 12], fill=1)                    # manivelle
    d.rectangle([22, 12, 23, 18], fill=1)


def champignon(d):
    d.pieslice([0, 1, 23, 22], 180, 360, fill=1)    # chapeau
    d.ellipse([4, 4, 7, 7], fill=0)                 # points
    d.ellipse([15, 4, 18, 7], fill=0)
    d.ellipse([10, 1, 13, 4], fill=0)
    d.rectangle([7, 12, 16, 22], fill=1)            # pied
    d.rectangle([9, 15, 10, 17], fill=0)
    d.rectangle([13, 15, 14, 17], fill=0)


def maison(d):
    d.polygon([(11, 0), (12, 0), (23, 10), (0, 10)], fill=1)   # toit
    d.rectangle([18, 1, 20, 6], fill=1)                         # cheminee
    d.rectangle([2, 10, 21, 23], fill=1)                        # murs
    d.rectangle([5, 13, 9, 17], fill=0)                         # fenetre gauche
    d.rectangle([14, 13, 18, 17], fill=0)                       # fenetre droite
    d.rectangle([10, 17, 13, 23], fill=0)                       # porte
    d.ellipse([10, 4, 13, 7], fill=0)                           # oeil-de-boeuf


IMAGES = [
    ("Coeur", render(16, 16, coeur)),
    ("Poisson", render(24, 16, poisson)),
    ("Fusee", render(16, 24, fusee)),
    ("Chat", render(24, 24, chat)),
    ("Maison", render(24, 24, maison)),
    ("Playdate", render(24, 24, console)),
]

if __name__ == '__main__':
    for name, art in IMAGES:
        print(name)
        print('\n'.join(art))
        print()
