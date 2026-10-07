-- Tutoriel : pages illustrees puis grille d'entrainement

local pd <const> = playdate
local gfx <const> = pd.graphics

local T = {}
Scenes.tutorial = T

-- Grille resolue servant d'exemple ('#' noir, 'o' blanc, chiffre = indice)
local SOLVED = { "#ooo4", "#####", "#2o#1", "#####", "#oo3#" }
local EMPTYG = { "....4", ".....", ".2..1", ".....", "...3." }

local PRACTICE = {
	grid = { "..3..", ".....", "..2.1", ".....", ".1.2." },
	sol = { "#...#", "#####", "#..#.", "#####", "#.#.." },
}

local pages = {
	{
		title = "Le Nurikabe",
		text = "La grille cache des iles blanches au milieu d'une mer noire. Les chiffres te donnent les iles : a toi de retrouver la mer !",
		ex = EMPTYG, cs = 22,
	},
	{
		title = "Regle 1 : les iles",
		text = "Chaque chiffre est dans une ile blanche qui compte exactement ce nombre de cases. Ici, l'ile du 4 est surlignee.",
		ex = SOLVED, cs = 22, hl = { { 1, 2 }, { 1, 3 }, { 1, 4 }, { 1, 5 } },
	},
	{
		title = "Regle 2 : un chiffre par ile",
		text = "Une ile ne contient qu'un seul chiffre, et deux iles ne se touchent jamais par un cote. Une case collee a deux iles est donc noire.",
		ex = { "o2#3oo" }, cs = 20, hl = { { 1, 3 } },
	},
	{
		title = "Regle 3 : une seule mer",
		text = "Toutes les cases noires forment une seule mer : on doit pouvoir aller de l'une a l'autre en passant par les cotes.",
		ex = SOLVED, cs = 22,
	},
	{
		title = "Regle 4 : pas de bassin",
		text = "La mer ne contient jamais de carre 2x2 noir. Le jeu te le signale avec un petit rond blanc au centre.",
		ex = { "o##o", "o##o", "oooo" }, cs = 26, pools = { { 1, 2 } },
	},
	{
		title = "Commandes",
		text = "✛ deplacer le curseur\nⒶ noircir / effacer\nⒷ poser un point (case blanche)\nMaintiens Ⓐ ou Ⓑ + ✛ pour peindre\n🎣 en arriere : annuler, en avant : refaire\nMenu : indice, recommencer",
	},
	{
		title = "Astuces",
		text = "- Autour d'un 1, tout est noir.\n- Une case qu'aucune ile ne peut atteindre est noire.\n- Si 3 cases d'un carre 2x2 sont noires, la 4e est blanche.\n- Une ile complete s'entoure de noir.",
		ex = { "###", "#1#", "###" }, cs = 24,
	},
	{
		title = "Les modes de jeu",
		text = "Niveaux : 4 difficultes de 12 grilles, de 7x7 a 12x12.\n\nMosaiques : chaque piece est une grille. Resous-les toutes et les cases noires dessinent une image secrete !",
	},
	{
		title = "A toi de jouer !",
		text = "Essaie une petite grille d'entrainement. Les erreurs de regle sont signalees : chiffre grise, rond blanc, croix.\n\nⒶ Commencer",
		ex = PRACTICE.grid, cs = 22,
	},
}

local page = 1

function T.enter(a)
	page = a.page or 1
end

function T.menu(m)
	m:addMenuItem("Accueil", function() App.go("home") end)
end

local function go(delta)
	local np = page + delta
	if np < 1 then
		App.go("home")
		return
	end
	if np > #pages then
		Save.data.tutoSeen = true
		Save.write()
		App.go("game", {
			puzzle = PRACTICE,
			key = "T:1",
			title = "Entrainement",
			subtitle = "Grille 5x5",
			practice = true,
			nextLabel = "Accueil",
			onBack = function() App.go("tutorial", { page = #pages }) end,
			onNext = function() App.go("home") end,
		})
		return
	end
	page = np
	UI.blip(delta > 0 and "G4" or "E4", 0.03)
	App.redraw()
end

function T.move(dr, dc)
	if dc ~= 0 then go(dc) end
end

function T.A(down) if down then go(1) end end
function T.B(down) if down then go(-1) end end

function T.crank(ticks)
	if ticks ~= 0 then go(ticks > 0 and 1 or -1) end
end

function T.draw()
	local p = pages[page]
	UI.big:drawText(p.title, 12, 8)
	UI.right(UI.font, page .. " / " .. #pages, 390, 14)
	gfx.drawLine(12, 40, 388, 40)

	local tx, tw = 12, 376
	if p.ex then
		local cs = p.cs
		local w, h = #p.ex[1] * cs, #p.ex * cs
		local ex, ey = 12 + math.floor((130 - w) / 2), 52 + math.floor((150 - h) / 2)
		UI.example(p.ex, ex, ey, cs, { hl = p.hl, pools = p.pools })
		gfx.setLineWidth(2)
		gfx.drawRect(ex - 1, ey - 1, w + 3, h + 3)
		gfx.setLineWidth(1)
		tx, tw = 156, 232
	end
	UI.wrap(p.text, tx, 52, tw, 160)

	-- pastilles de pagination
	for k = 1, #pages do
		local x = 200 - (#pages * 12) / 2 + (k - 1) * 12 + 6
		if k == page then
			gfx.fillCircleAtPoint(x, 226, 4)
		else
			gfx.drawCircleAtPoint(x, 226, 3)
		end
	end
	UI.font:drawText("Ⓑ", 12, 218)
	UI.right(UI.font, "Ⓐ", 388, 218)
end
