-- Menu d'accueil

local pd <const> = playdate
local gfx <const> = pd.graphics

local H = {}
Scenes.home = H

local items = {
	{ label = "Niveaux", desc = "Choisis ta grille parmi 4 difficultes." },
	{ label = "Mosaiques", desc = "Resous les pieces pour reveler une image." },
	{ label = "Tutoriel", desc = "Les regles et les commandes en 2 minutes." },
}
local sel = 1
local t0 = 0

-- Decor : un petit Nurikabe resolu qui se dessine case par case
local DECO = {
	"2#5oo#",
	"o#oo##",
	"#####1",
	"#1#o##",
	"3##o#2",
	"oo#3#o",
}
local decoCells = {}

function H.enter()
	t0 = pd.getCurrentTimeMilliseconds()
	if not Save.data.tutoSeen then sel = 3 end
	decoCells = {}
	for r = 1, #DECO do
		for c = 1, #DECO[r] do
			if DECO[r]:sub(c, c) == "#" then decoCells[#decoCells + 1] = { r, c } end
		end
	end
end

function H.update()
	if pd.getCurrentTimeMilliseconds() - t0 < #decoCells * 60 + 100 then App.redraw() end
end

function H.move(dr, dc)
	if dr ~= 0 then
		sel = (sel - 1 + dr) % #items + 1
		UI.blip("E4", 0.02)
		App.redraw()
	end
end

function H.A(down)
	if not down then return end
	UI.blip("G4")
	if sel == 1 then
		App.go("levels")
	elseif sel == 2 then
		App.go("gallery")
	else
		App.go("tutorial")
	end
end

local function drawDeco(x, y, cs)
	local shown = math.floor((pd.getCurrentTimeMilliseconds() - t0) / 60)
	local rows = {}
	for r = 1, #DECO do rows[r] = DECO[r]:gsub("#", "."):gsub("o", ".") end
	for k = 1, math.min(shown, #decoCells) do
		local r, c = decoCells[k][1], decoCells[k][2]
		rows[r] = rows[r]:sub(1, c - 1) .. "#" .. rows[r]:sub(c + 1)
	end
	UI.example(rows, x, y, cs)
	gfx.setLineWidth(2)
	gfx.drawRect(x - 1, y - 1, #DECO[1] * cs + 3, #DECO * cs + 3)
	gfx.setLineWidth(1)
end

function H.draw()
	UI.big:drawText("NURIKABE", 20, 18)
	UI.font:drawText("Iles et mer", 22, 50)

	for k, it in ipairs(items) do
		local y = 82 + (k - 1) * 40
		if k == sel then
			UI.pill(UI.bold, it.label, 20, y, 150, 30)
		else
			gfx.setColor(gfx.kColorBlack)
			gfx.drawRoundRect(20, y, 150, 30, 15)
			UI.centered(UI.font, it.label, 95, y + 15)
		end
		if k == 3 and not Save.data.tutoSeen then
			UI.font:drawText("Nouveau !", 176, y + 7)
		end
	end
	UI.wrap(items[sel].desc, 20, 206, 210, 34)

	drawDeco(250, 30, 23)
	local ld, lt = Save.countLevels()
	local md, mt = Save.countMosaics()
	UI.font:drawText("Grilles " .. ld .. "/" .. lt, 252, 182)
	UI.font:drawText("Mosaiques " .. md .. "/" .. mt, 252, 202)
end
