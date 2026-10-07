-- Mode Mosaiques : galerie des images, puis choix des pieces d'une image.
-- Chaque piece est un Nurikabe 8x8 ; une fois toutes resolues, les solutions forment l'image.

local pd <const> = playdate
local gfx <const> = pd.graphics

local TILE <const> = 8

-- Dessine une mosaique : pieces resolues (solution), en cours (grise claire) ou a faire (grise).
-- opts.sel = piece selectionnee, opts.flash = piece qui vient d'etre resolue, opts.clean = image d'origine
local function drawMosaic(m, x, y, px, opts)
	opts = opts or {}
	local mo = MOSAICS[m]
	local ts = TILE * px
	local now = pd.getCurrentTimeMilliseconds()
	for t = 1, #mo.tiles do
		local tr, tc = math.floor((t - 1) / mo.cols), (t - 1) % mo.cols
		local tx, ty = x + tc * ts, y + tr * ts
		local key = Save.mosaicKey(m, t)
		local revealed = Save.isSolved(key)
		if opts.flash == t and opts.flashUntil and now < opts.flashUntil then
			-- revelation progressive de la piece, ligne par ligne
			local rowsShown = math.floor(TILE * (1 - (opts.flashUntil - now) / 800))
			revealed = false
			for r = 1, math.max(0, rowsShown) do
				local row = mo.tiles[t].sol[r]
				for c = 1, TILE do
					if row:sub(c, c) == "#" then gfx.fillRect(tx + (c - 1) * px, ty + (r - 1) * px, px, px) end
				end
			end
		elseif opts.clean then
			for r = 1, TILE do
				local row = mo.image[tr * TILE + r]
				for c = 1, TILE do
					if row:sub(tc * TILE + c, tc * TILE + c) == "#" then
						gfx.fillRect(tx + (c - 1) * px, ty + (r - 1) * px, px, px)
					end
				end
			end
		elseif revealed then
			for r = 1, TILE do
				local row = mo.tiles[t].sol[r]
				for c = 1, TILE do
					if row:sub(c, c) == "#" then gfx.fillRect(tx + (c - 1) * px, ty + (r - 1) * px, px, px) end
				end
			end
		else
			UI.gray(Save.data.progress[key] and 0.75 or 0.5)
			gfx.fillRect(tx, ty, ts, ts)
			gfx.setColor(gfx.kColorBlack)
			if ts >= 40 then
				gfx.setColor(gfx.kColorWhite)
				gfx.fillCircleAtPoint(tx + ts / 2, ty + ts / 2, 11)
				gfx.setColor(gfx.kColorBlack)
				UI.centered(UI.bold, tostring(t), tx + ts / 2, ty + ts / 2)
			end
		end
	end
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(x - 1, y - 1, mo.cols * ts + 2, mo.rows * ts + 2)
	if opts.sel then
		local tr, tc = math.floor((opts.sel - 1) / mo.cols), (opts.sel - 1) % mo.cols
		local tx, ty = x + tc * ts, y + tr * ts
		-- cadre noir epais + lisere blanc : visible sur le gris comme sur le noir
		gfx.setColor(gfx.kColorBlack)
		gfx.setLineWidth(4)
		gfx.drawRect(tx - 1, ty - 1, ts + 2, ts + 2)
		gfx.setColor(gfx.kColorWhite)
		gfx.setLineWidth(2)
		gfx.drawRect(tx + 2, ty + 2, ts - 4, ts - 4)
		gfx.setLineWidth(1)
		gfx.setColor(gfx.kColorBlack)
	end
end

local function isComplete(m)
	local d, t = Save.mosaicProgress(m)
	return d == t
end

---------------------------------------------------------------- galerie

local Gal = {}
Scenes.gallery = Gal
local gsel = 1
local GCOLS <const> = 3

function Gal.enter()
	gsel = math.min(Save.data.lastMosaic[1] or 1, #MOSAICS)
end

function Gal.menu(m)
	m:addMenuItem("Accueil", function() App.go("home") end)
end

function Gal.move(dr, dc)
	local n = #MOSAICS
	local ni = gsel + dc + dr * GCOLS
	if ni >= 1 and ni <= n then
		gsel = ni
		UI.blip("E4", 0.02)
		App.redraw()
	end
end

function Gal.A(down)
	if down then
		Save.data.lastMosaic = { gsel, 1 }
		App.go("mosaic", { m = gsel })
	end
end

function Gal.B(down)
	if down then App.go("home") end
end

function Gal.draw()
	UI.big:drawText("Mosaiques", 10, 4)
	local md, mt = Save.countMosaics()
	UI.right(UI.font, md .. " / " .. mt .. " terminees", 390, 12)

	local cw, ch = 124, 88
	for m = 1, #MOSAICS do
		local mo = MOSAICS[m]
		local r, c = math.floor((m - 1) / GCOLS), (m - 1) % GCOLS
		local x, y = 8 + c * (cw + 4), 36 + r * (ch + 4)
		local px = math.floor(math.min(110 / (mo.cols * TILE), 62 / (mo.rows * TILE)))
		local w, h = mo.cols * TILE * px, mo.rows * TILE * px
		drawMosaic(m, x + math.floor((cw - w) / 2), y + 6, px)
		local d, t = Save.mosaicProgress(m)
		local label = (d == t) and mo.name or "? ? ?"
		UI.centered(d == t and UI.bold or UI.font, label .. "  " .. d .. "/" .. t, x + cw / 2, y + ch - 11)
		if m == gsel then
			gfx.setLineWidth(2)
			gfx.drawRoundRect(x, y, cw, ch, 8)
			gfx.setLineWidth(1)
		end
	end
	UI.font:drawText("Ⓐ Ouvrir   Ⓑ Accueil", 10, 221)
end

---------------------------------------------------------------- une mosaique

local M = {}
Scenes.mosaic = M
local m, sel = 1, 1
local flashTile, flashUntil = nil, 0
local celebrate = 0
local showClean = false

local function startTile(t)
	sel = t
	Save.data.lastMosaic = { m, t }
	local mo = MOSAICS[m]
	App.go("game", {
		puzzle = mo.tiles[t],
		key = Save.mosaicKey(m, t),
		title = Save.mosaicProgress(m) == #mo.tiles and mo.name or "Image ? ? ?",
		subtitle = "Piece " .. t .. " / " .. #mo.tiles,
		mosaic = { m = m, t = t },
		nextLabel = "Mosaique",
		onBack = function() App.go("mosaic", { m = m, sel = t }) end,
		onNext = function() App.go("mosaic", { m = m, sel = t, justSolved = true }) end,
	})
end

function M.enter(a)
	m = a.m or m
	sel = a.sel or Save.data.lastMosaic[2] or 1
	if sel > #MOSAICS[m].tiles then sel = 1 end
	showClean = false
	flashTile = nil
	celebrate = 0
	M.jingled = false
	if a.justSolved and Save.isSolved(Save.mosaicKey(m, sel)) then
		flashTile, flashUntil = sel, pd.getCurrentTimeMilliseconds() + 800
		if isComplete(m) then
			celebrate = pd.getCurrentTimeMilliseconds() + 800
		else
			-- piece suivante non resolue
			local mo = MOSAICS[m]
			for k = 1, #mo.tiles do
				local t = (sel - 1 + k) % #mo.tiles + 1
				if not Save.isSolved(Save.mosaicKey(m, t)) then sel = t break end
			end
		end
	end
end

function M.menu(menu)
	menu:addMenuItem("Galerie", function() App.go("gallery") end)
	menu:addMenuItem("Accueil", function() App.go("home") end)
end

function M.update()
	local now = pd.getCurrentTimeMilliseconds()
	if flashTile and now < flashUntil + 50 then App.redraw() end
	if celebrate > 0 and now < celebrate + 2500 then
		App.redraw()
		if now >= celebrate and not M.jingled then
			M.jingled = true
			UI.jingle({ "C5", "E5", "G5", "C6", "G5", "C6" })
		end
	end
end

function M.move(dr, dc)
	local mo = MOSAICS[m]
	local r, c = math.floor((sel - 1) / mo.cols), (sel - 1) % mo.cols
	r = math.max(0, math.min(mo.rows - 1, r + dr))
	c = math.max(0, math.min(mo.cols - 1, c + dc))
	sel = r * mo.cols + c + 1
	showClean = false
	UI.blip("E4", 0.02)
	App.redraw()
end

function M.A(down)
	if down then startTile(sel) end
end

function M.B(down)
	if down then App.go("gallery") end
end

function M.crank(ticks)
	-- une fois l'image terminee, la manivelle bascule entre les solutions et l'image d'origine
	if isComplete(m) then
		showClean = ticks > 0
		App.redraw()
	end
end

function M.draw()
	local mo = MOSAICS[m]
	local px = math.floor(math.min(224 / (mo.cols * TILE), 224 / (mo.rows * TILE)))
	local w, h = mo.cols * TILE * px, mo.rows * TILE * px
	local x, y = math.floor((240 - w) / 2), math.floor((240 - h) / 2)
	local complete = isComplete(m)
	drawMosaic(m, x, y, px, {
		sel = (not complete or not showClean) and sel or nil,
		flash = flashTile, flashUntil = flashUntil, clean = showClean,
	})

	local pxl = 250
	local d, t = Save.mosaicProgress(m)
	UI.bold:drawText(complete and mo.name or "Image ? ? ?", pxl, 8)
	UI.font:drawText("Pieces " .. d .. " / " .. t, pxl, 28)
	-- barre de progression
	gfx.drawRoundRect(pxl, 50, 136, 10, 5)
	if d > 0 then gfx.fillRoundRect(pxl, 50, math.max(10, math.floor(136 * d / t)), 10, 5) end

	local key = Save.mosaicKey(m, sel)
	local info
	if Save.isSolved(key) then
		info = "Resolue en " .. UI.formatTime(Save.data.solved[key])
	elseif Save.data.progress[key] then
		info = "En cours - " .. UI.formatTime(Save.data.progress[key].time)
	else
		info = "A resoudre"
	end
	UI.bold:drawText("Piece " .. sel, pxl, 76)
	UI.font:drawText(info, pxl, 96)

	if complete then
		UI.wrap("Image terminee ! Tourne la manivelle pour voir le modele.", pxl, 124, 145, 60)
	else
		UI.wrap("Resous chaque piece : les cases noires dessinent l'image.", pxl, 124, 145, 60)
	end
	UI.font:drawText("Ⓐ Jouer   Ⓑ Galerie", pxl, 216)

	local now = pd.getCurrentTimeMilliseconds()
	if celebrate > 0 and now >= celebrate and now < celebrate + 2500 then
		UI.pill(UI.bold, "Mosaique terminee : " .. mo.name .. " !", 20, 104, 360, 32)
	end
end
