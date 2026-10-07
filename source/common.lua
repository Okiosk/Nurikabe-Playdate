-- Outils partages : polices, sons, sauvegarde, gestion des scenes, dessin.
-- (La police systeme de la Playdate n'a pas d'accents : les textes sont ecrits sans.)

local pd <const> = playdate
local gfx <const> = pd.graphics

---------------------------------------------------------------- polices

UI = {}
UI.font = gfx.getSystemFont()
UI.bold = gfx.getSystemFont(gfx.font.kVariantBold)
UI.big = gfx.font.new("/System/Fonts/Roobert-20-Medium")
if not UI.big then
	-- repli : texte gras dessine en double taille
	local cache = {}
	UI.big = {
		getHeight = function() return UI.bold:getHeight() * 2 end,
		getTextWidth = function(_, t) return UI.bold:getTextWidth(t) * 2 end,
		drawText = function(_, t, x, y)
			local img = cache[t]
			if not img then
				img = gfx.image.new(UI.bold:getTextWidth(t), UI.bold:getHeight())
				gfx.pushContext(img)
				UI.bold:drawText(t, 0, 0)
				gfx.popContext()
				cache[t] = img
			end
			img:drawScaled(x, y, 2)
		end,
	}
end

function UI.centered(font, text, cx, cy)
	local w, h = font:getTextWidth(text), font:getHeight()
	font:drawText(text, math.floor(cx - w / 2), math.floor(cy - h / 2) + 1)
end

function UI.right(font, text, rx, y)
	font:drawText(text, rx - font:getTextWidth(text), y)
end

-- Texte blanc sur fond noir arrondi
function UI.pill(font, text, x, y, w, h)
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRoundRect(x, y, w, h, math.floor(h / 2))
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	UI.centered(font, text, x + w / 2, y + h / 2)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

-- Texte avec retour a la ligne automatique (police normale)
function UI.wrap(text, x, y, w, h, font)
	gfx.setFont(font or UI.font)
	gfx.drawTextInRect(text, x, y, w, h)
end

function UI.gray(alpha)
	gfx.setColor(gfx.kColorBlack)
	gfx.setDitherPattern(alpha or 0.5, gfx.image.kDitherTypeBayer2x2)
end

function UI.formatTime(ms)
	local s = math.floor((ms or 0) / 1000)
	local h = math.floor(s / 3600)
	if h > 0 then
		return string.format("%d:%02d:%02d", h, math.floor(s / 60) % 60, s % 60)
	end
	return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

-- Petite grille d'exemple (tutoriel, decor). `rows` : '#' noir, '.' vide, 'o' point, chiffre = indice.
-- opts.hl = { {r,c}, ... } cases surlignees ; opts.pools = { {r,c}, ... } coins haut-gauche de blocs 2x2.
function UI.example(rows, x, y, cs, opts)
	opts = opts or {}
	local h, w = #rows, #rows[1]
	for _, p in ipairs(opts.hl or {}) do
		if rows[p[1]]:sub(p[2], p[2]) ~= "#" then
			UI.gray(0.75)
			gfx.fillRect(x + (p[2] - 1) * cs, y + (p[1] - 1) * cs, cs, cs)
		end
	end
	gfx.setColor(gfx.kColorBlack)
	for r = 1, h do
		for c = 1, w do
			local ch = rows[r]:sub(c, c)
			local cx, cy = x + (c - 1) * cs, y + (r - 1) * cs
			if ch == "#" then
				gfx.fillRect(cx, cy, cs, cs)
			elseif ch == "o" then
				gfx.fillCircleAtPoint(cx + cs / 2, cy + cs / 2, math.max(1, math.floor(cs / 10)))
			elseif ch:match("%d") then
				UI.centered(cs >= 16 and UI.bold or UI.font, ch, cx + cs / 2, cy + cs / 2)
			end
		end
	end
	for k = 0, w do gfx.drawLine(x + k * cs, y, x + k * cs, y + h * cs) end
	for k = 0, h do gfx.drawLine(x, y + k * cs, x + w * cs, y + k * cs) end
	for _, p in ipairs(opts.hl or {}) do
		if rows[p[1]]:sub(p[2], p[2]) == "#" then
			gfx.setColor(gfx.kColorWhite)
			gfx.setLineWidth(2)
			gfx.drawRect(x + (p[2] - 1) * cs + 3, y + (p[1] - 1) * cs + 3, cs - 5, cs - 5)
			gfx.setLineWidth(1)
			gfx.setColor(gfx.kColorBlack)
		end
	end
	for _, p in ipairs(opts.pools or {}) do
		local px, py = x + p[2] * cs, y + p[1] * cs
		gfx.setColor(gfx.kColorWhite)
		gfx.fillCircleAtPoint(px, py, math.max(3, math.floor(cs / 5)))
		gfx.setColor(gfx.kColorBlack)
		gfx.drawCircleAtPoint(px, py, math.max(3, math.floor(cs / 5)))
	end
end

---------------------------------------------------------------- sons

local synth = pd.sound.synth.new(pd.sound.kWaveSquare)
synth:setADSR(0, 0.05, 0.2, 0.05)

function UI.blip(note, len) synth:playNote(note, 0.15, len or 0.04) end

function UI.jingle(notes)
	notes = notes or { "C5", "E5", "G5", "C6" }
	for k, note in ipairs(notes) do
		pd.timer.performAfterDelay((k - 1) * 110, function() UI.blip(note, 0.09) end)
	end
end

---------------------------------------------------------------- sauvegarde

Save = {}
local SAVE_VERSION <const> = 2

do
	local ok, data = pcall(pd.datastore.read)
	if not ok or type(data) ~= "table" or data.version ~= SAVE_VERSION then data = {} end
	data.version = SAVE_VERSION
	data.solved = data.solved or {}     -- [cle] = meilleur temps (ms)
	data.progress = data.progress or {} -- [cle] = { cells = "...", time = ms, hints = n }
	data.lastLevel = data.lastLevel or { 1, 1 }
	data.lastMosaic = data.lastMosaic or { 1, 1 }
	Save.data = data
end
Save.failed = false

function Save.write()
	local ok, err = pcall(pd.datastore.write, Save.data)
	if not ok then
		print("Sauvegarde impossible : " .. tostring(err))
		Save.failed = true
	end
end

function Save.levelKey(l, i) return "L" .. PUZZLES[l].size .. ":" .. i end
function Save.mosaicKey(m, t) return "M" .. m .. ":" .. t end

function Save.isSolved(key) return Save.data.solved[key] ~= nil end

function Save.countLevels()
	local done, total = 0, 0
	for l, lv in ipairs(PUZZLES) do
		for i = 1, #lv.list do
			total = total + 1
			if Save.isSolved(Save.levelKey(l, i)) then done = done + 1 end
		end
	end
	return done, total
end

function Save.mosaicProgress(m)
	local mo = MOSAICS[m]
	local done = 0
	for t = 1, #mo.tiles do
		if Save.isSolved(Save.mosaicKey(m, t)) then done = done + 1 end
	end
	return done, #mo.tiles
end

function Save.countMosaics()
	local done = 0
	for m = 1, #MOSAICS do
		local d, t = Save.mosaicProgress(m)
		if d == t then done = done + 1 end
	end
	return done, #MOSAICS
end

---------------------------------------------------------------- scenes

-- Une scene est une table avec (toutes optionnelles) :
--   enter(args), leave(), update(dt), draw(), move(dr, dc),
--   A(down), B(down), crank(ticks), menu(sysmenu)
Scenes = {}
App = { scene = nil, name = nil, dirty = true }

function App.go(name, args)
	if App.scene and App.scene.leave then App.scene.leave() end
	App.name = name
	App.scene = Scenes[name]
	local m = pd.getSystemMenu()
	m:removeAllMenuItems()
	if App.scene.enter then App.scene.enter(args or {}) end
	if App.scene.menu then App.scene.menu(m) end
	App.dirty = true
end

function App.redraw() App.dirty = true end
