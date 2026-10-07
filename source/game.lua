-- Scene de jeu : resolution d'une grille.
-- args : puzzle, key, title, subtitle, onBack(), onNext() (optionnel), nextLabel,
--        mosaic = { m = , t = } (optionnel, pour la mini-carte), practice = true

local pd <const> = playdate
local gfx <const> = pd.graphics

local G = {}
Scenes.game = G

local args, board
local cursorR, cursorC = 1, 1
local painting, paintFrom, paintTo
local elapsed, hints, solved = 0, 0, false
local lastSecond = -1
local flashCell, flashUntil = nil, 0
local winAt = 0

local function saveProgress()
	if not board then return end
	local data = Save.data
	if not solved then
		local empty = true
		for i = 1, board.n * board.n do
			if board.cell[i] ~= EMPTY then empty = false break end
		end
		if empty and elapsed < 1000 then
			data.progress[args.key] = nil
		else
			data.progress[args.key] = { cells = board:serialize(), time = elapsed, hints = hints }
		end
	end
	Save.write()
end
G.saveProgress = saveProgress

local function checkWin()
	if solved or not board:isSolved() then return end
	solved = true
	painting = nil
	board:fillDots()
	local data = Save.data
	local best = data.solved[args.key]
	if not best or elapsed < best then data.solved[args.key] = elapsed end
	data.progress[args.key] = nil
	if args.onSolved then args.onSolved() end
	Save.write()
	winAt = pd.getCurrentTimeMilliseconds()
	UI.jingle()
end

local function layout()
	local n = board.n
	local cs = math.min(32, math.floor(224 / n))
	local gw = n * cs
	return cs, math.floor((240 - gw) / 2), math.floor((240 - gw) / 2)
end

---------------------------------------------------------------- cycle de vie

function G.enter(a)
	args = a
	board = Board.new(a.puzzle)
	elapsed, hints, solved = 0, 0, false
	local prog = Save.data.progress[a.key]
	if prog then
		board:load(prog.cells)
		elapsed = prog.time or 0
		hints = prog.hints or 0
	end
	cursorR, cursorC = math.ceil(board.n / 2), math.ceil(board.n / 2)
	painting = nil
	lastSecond = -1
	flashCell = nil
	pd.getCrankTicks(12)
end

function G.leave()
	if painting then
		painting = nil
		board:endStroke()
	end
	saveProgress()
end

function G.menu(m)
	m:addMenuItem("Retour", function() args.onBack() end)
	m:addMenuItem("Recommencer", function()
		if not solved then
			board:reset()
			App.redraw()
		end
	end)
	m:addMenuItem("Indice", function()
		if solved then return end
		local i = board:hint(board:index(cursorR, cursorC))
		if i then
			hints = hints + 1
			cursorR, cursorC = board:rc(i)
			flashCell, flashUntil = i, pd.getCurrentTimeMilliseconds() + 900
			checkWin()
			App.redraw()
		end
	end)
end

function G.pause()
	if painting then G.A(false); G.B(false) end
	saveProgress()
end

function G.update(dt)
	if not solved then
		elapsed = elapsed + math.min(dt, 200)
		local sec = math.floor(elapsed / 1000)
		if sec ~= lastSecond then
			lastSecond = sec
			App.redraw()
		end
	end
	local now = pd.getCurrentTimeMilliseconds()
	if flashCell and now < flashUntil + 50 then App.redraw() end
	if solved and now - winAt < 600 then App.redraw() end
end

---------------------------------------------------------------- commandes

local function applyPaint()
	if not painting then return end
	local i = board:index(cursorR, cursorC)
	if board.clue[i] then return end
	if paintTo == EMPTY then
		if board.cell[i] == paintFrom then board:setCell(i, EMPTY) end
	else
		board:setCell(i, paintTo)
	end
end

function G.move(dr, dc)
	if solved then return end
	local n = board.n
	cursorR = (cursorR - 1 + dr) % n + 1 -- le curseur fait le tour de la grille
	cursorC = (cursorC - 1 + dc) % n + 1
	applyPaint()
	App.redraw()
end

local function beginPaint(button, target)
	local i = board:index(cursorR, cursorC)
	if board.clue[i] then
		UI.blip("C3", 0.02)
		return
	end
	painting = button
	paintFrom = board.cell[i]
	paintTo = (paintFrom == target) and EMPTY or target
	board:beginStroke()
	applyPaint()
	UI.blip(paintTo == BLACK and "C4" or (paintTo == DOT and "G4" or "E3"))
	App.redraw()
end

local function endPaint(button)
	if painting ~= button then return end
	painting = nil
	board:endStroke()
	checkWin()
	App.redraw()
end

function G.A(down)
	if down then
		if solved then
			if pd.getCurrentTimeMilliseconds() - winAt < 400 then return end
			if args.onNext then args.onNext() else args.onBack() end
		elseif not painting then
			beginPaint("A", BLACK)
		end
	else
		endPaint("A")
	end
end

function G.B(down)
	if down then
		if solved then
			if pd.getCurrentTimeMilliseconds() - winAt < 400 then return end
			args.onBack()
		elseif not painting then
			beginPaint("B", DOT)
		end
	else
		endPaint("B")
	end
end

function G.crank(ticks)
	if solved or painting then return end
	local changed = false
	if ticks < 0 then
		for _ = 1, -ticks do changed = board:undo() or changed end
	else
		for _ = 1, ticks do changed = board:redo() or changed end
	end
	if changed then
		UI.blip(ticks < 0 and "D4" or "F4", 0.03)
		checkWin()
		App.redraw()
	end
end

---------------------------------------------------------------- dessin

local function drawBoard()
	local n = board.n
	local cs, gx, gy = layout()
	local now = pd.getCurrentTimeMilliseconds()
	local font = cs >= 20 and UI.bold or UI.font

	for i = 1, n * n do
		local r, c = board:rc(i)
		local x, y = gx + (c - 1) * cs, gy + (r - 1) * cs
		local v = board.cell[i]
		if board.clue[i] then
			if board.badClue[i] then
				UI.gray(0.5)
				gfx.fillRect(x, y, cs, cs)
				gfx.setColor(gfx.kColorWhite)
				gfx.fillCircleAtPoint(x + cs / 2, y + cs / 2, cs / 2 - 2)
				gfx.setColor(gfx.kColorBlack)
				gfx.drawCircleAtPoint(x + cs / 2, y + cs / 2, cs / 2 - 2)
			end
			UI.centered(UI.bold, tostring(board.clue[i]), x + cs / 2, y + cs / 2)
		elseif v == BLACK then
			gfx.setColor(gfx.kColorBlack)
			gfx.fillRect(x, y, cs, cs)
		elseif v == DOT then
			gfx.setColor(gfx.kColorBlack)
			if board.badDot[i] then
				local d = math.max(2, math.floor(cs / 6))
				gfx.setLineWidth(2)
				gfx.drawLine(x + cs / 2 - d, y + cs / 2 - d, x + cs / 2 + d, y + cs / 2 + d)
				gfx.drawLine(x + cs / 2 - d, y + cs / 2 + d, x + cs / 2 + d, y + cs / 2 - d)
				gfx.setLineWidth(1)
			else
				gfx.fillCircleAtPoint(x + cs / 2, y + cs / 2, math.max(2, math.floor(cs / 10)))
			end
		end
	end

	gfx.setColor(gfx.kColorBlack)
	for k = 0, n do
		gfx.drawLine(gx + k * cs, gy, gx + k * cs, gy + n * cs)
		gfx.drawLine(gx, gy + k * cs, gx + n * cs, gy + k * cs)
	end
	gfx.setLineWidth(2)
	gfx.drawRect(gx - 1, gy - 1, n * cs + 3, n * cs + 3)
	gfx.setLineWidth(1)

	local pr = math.max(3, math.floor(cs / 5))
	for i in pairs(board.pool) do
		local r, c = board:rc(i)
		local px, py = gx + c * cs, gy + r * cs
		gfx.setColor(gfx.kColorWhite)
		gfx.fillCircleAtPoint(px, py, pr)
		gfx.setColor(gfx.kColorBlack)
		gfx.drawCircleAtPoint(px, py, pr)
	end

	if flashCell and now < flashUntil and math.floor((flashUntil - now) / 150) % 2 == 0 then
		local r, c = board:rc(flashCell)
		gfx.setColor(gfx.kColorXOR)
		gfx.fillRect(gx + (c - 1) * cs + 2, gy + (r - 1) * cs + 2, cs - 3, cs - 3)
		gfx.setColor(gfx.kColorBlack)
	end

	if not solved then
		local x, y = gx + (cursorC - 1) * cs, gy + (cursorR - 1) * cs
		local t = cs >= 24 and 3 or 2
		gfx.setColor(gfx.kColorXOR)
		gfx.fillRect(x + 1, y + 1, cs - 1, t)
		gfx.fillRect(x + 1, y + cs - t, cs - 1, t)
		gfx.fillRect(x + 1, y + 1 + t, t, cs - 1 - 2 * t)
		gfx.fillRect(x + cs - t, y + 1 + t, t, cs - 1 - 2 * t)
		gfx.setColor(gfx.kColorBlack)
	end
end

local function drawMiniMap(x, y)
	local mo = MOSAICS[args.mosaic.m]
	local px = math.max(1, math.floor(math.min(140 / (mo.cols * 8), 56 / (mo.rows * 8))))
	local ts = 8 * px
	for t = 1, #mo.tiles do
		local tr, tc = math.floor((t - 1) / mo.cols), (t - 1) % mo.cols
		local tx, ty = x + tc * ts, y + tr * ts
		local isCurrent = t == args.mosaic.t
		if Save.isSolved(Save.mosaicKey(args.mosaic.m, t)) and not isCurrent then
			local sol = mo.tiles[t].sol
			for r = 1, 8 do
				for c = 1, 8 do
					if sol[r]:sub(c, c) == "#" then gfx.fillRect(tx + (c - 1) * px, ty + (r - 1) * px, px, px) end
				end
			end
		elseif isCurrent then
			gfx.setLineWidth(2)
			gfx.drawRect(tx + 1, ty + 1, ts - 2, ts - 2)
			gfx.setLineWidth(1)
			if solved then
				local sol = mo.tiles[t].sol
				for r = 1, 8 do
					for c = 1, 8 do
						if sol[r]:sub(c, c) == "#" then gfx.fillRect(tx + (c - 1) * px, ty + (r - 1) * px, px, px) end
					end
				end
			end
		else
			UI.gray(0.85)
			gfx.fillRect(tx, ty, ts, ts)
			gfx.setColor(gfx.kColorBlack)
		end
	end
	gfx.drawRect(x - 1, y - 1, mo.cols * ts + 2, mo.rows * ts + 2)
end

local function drawPanel()
	local x = 250
	UI.bold:drawText(args.title, x, 8)
	UI.font:drawText(args.subtitle, x, 28)

	UI.pill(UI.bold, UI.formatTime(elapsed), x, 52, 136, 28)
	if hints > 0 then UI.font:drawText("Indices : " .. hints, x, 86) end

	if args.mosaic then
		drawMiniMap(x + 4, 110)
	elseif args.practice then
		UI.wrap("Noircis la mer. Chaque chiffre = une ile de cette taille.", x, 106, 145, 64)
	end

	UI.font:drawText("Ⓐ Noir   Ⓑ Point", x, 176)
	UI.font:drawText("🎣 Annuler/Refaire", x, 196)
	UI.font:drawText("Menu : Indice...", x, 216)
end

local function drawWin()
	local w, h = 236, 108
	local x, y = math.floor((400 - w) / 2), math.floor((240 - h) / 2)
	local t = math.min(1, (pd.getCurrentTimeMilliseconds() - winAt) / 300)
	y = math.floor(240 - (240 - y) * t) -- petite entree par le bas
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRoundRect(x - 3, y - 3, w + 6, h + 6, 10)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRoundRect(x, y, w, h, 8)
	gfx.setColor(gfx.kColorBlack)
	UI.centered(UI.big, "Bravo !", 200, y + 22)
	local best = Save.data.solved[args.key]
	UI.centered(UI.font, "Temps " .. UI.formatTime(elapsed) .. "   Record " .. UI.formatTime(best or elapsed), 200, y + 52)
	UI.centered(UI.font, "Ⓐ " .. (args.nextLabel or "Suivante") .. "    Ⓑ Retour", 200, y + 82)
	if Save.failed then
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(110, y + h + 6, 180, 20)
		gfx.setColor(gfx.kColorBlack)
		UI.centered(UI.font, "(sauvegarde impossible)", 200, y + h + 16)
	end
end

function G.draw()
	drawBoard()
	drawPanel()
	if solved then drawWin() end
end
