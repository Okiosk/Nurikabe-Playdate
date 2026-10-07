-- Mode Niveaux : choix de la difficulte et de la grille

local pd <const> = playdate
local gfx <const> = pd.graphics

local L = {}
Scenes.levels = L

local level, index = 1, 1
local focus = 1 -- 0 = onglets, 1 = grilles
local COLS <const> = 6

local function startPuzzle(l, i)
	level, index = l, i
	Save.data.lastLevel = { l, i }
	local lv = PUZZLES[l]
	App.go("game", {
		puzzle = lv.list[i],
		key = Save.levelKey(l, i),
		title = lv.name .. " " .. lv.size .. "x" .. lv.size,
		subtitle = "Grille " .. i .. " / " .. #lv.list,
		onBack = function() App.go("levels") end,
		onNext = function()
			local nl, ni = l, i + 1
			if ni > #lv.list then
				nl, ni = l + 1, 1
				if nl > #PUZZLES then nl = 1 end
			end
			startPuzzle(nl, ni)
		end,
	})
end

function L.enter()
	level = math.min(Save.data.lastLevel[1] or 1, #PUZZLES)
	index = math.min(Save.data.lastLevel[2] or 1, #PUZZLES[level].list)
	focus = 1
end

function L.menu(m)
	m:addMenuItem("Accueil", function() App.go("home") end)
end

function L.move(dr, dc)
	if focus == 0 then
		if dc ~= 0 then
			level = (level - 1 + dc) % #PUZZLES + 1
			index = math.min(index, #PUZZLES[level].list)
			UI.blip("A4")
		elseif dr > 0 then
			focus = 1
		end
	else
		local count = #PUZZLES[level].list
		local i = index - 1
		local r, c = math.floor(i / COLS), i % COLS
		if dr < 0 and r == 0 then
			focus = 0
		else
			r, c = r + dr, c + dc
			if c < 0 then c = COLS - 1; r = r - 1 end
			if c >= COLS then c = 0; r = r + 1 end
			local ni = r * COLS + c
			if ni >= 0 and ni < count then index = ni + 1 end
		end
		UI.blip("E4", 0.02)
	end
	App.redraw()
end

function L.A(down)
	if not down then return end
	if focus == 0 then
		focus = 1
		App.redraw()
	else
		startPuzzle(level, index)
	end
end

function L.B(down)
	if down then App.go("home") end
end

local function drawPreview(l, i, px, py, size)
	local p = PUZZLES[l].list[i]
	local n = #p.grid
	local cs = math.floor(size / n)
	local s = cs * n
	local ox, oy = px + math.floor((size - s) / 2), py + math.floor((size - s) / 2)
	local key = Save.levelKey(l, i)
	local cells
	if Save.isSolved(key) then
		cells = {}
		for r = 1, n do
			for c = 1, n do cells[(r - 1) * n + c] = p.sol[r]:sub(c, c) == "#" and BLACK or EMPTY end
		end
	elseif Save.data.progress[key] then
		cells = {}
		local str = Save.data.progress[key].cells
		for j = 1, #str do cells[j] = tonumber(str:sub(j, j)) end
	end
	for r = 1, n do
		for c = 1, n do
			local x, y = ox + (c - 1) * cs, oy + (r - 1) * cs
			local j = (r - 1) * n + c
			if p.grid[r]:sub(c, c) ~= "." then
				gfx.fillCircleAtPoint(x + cs / 2, y + cs / 2, math.max(2, math.floor(cs / 3)))
			elseif cells and cells[j] == BLACK then
				UI.gray(0.25)
				gfx.fillRect(x, y, cs, cs)
				gfx.setColor(gfx.kColorBlack)
			end
		end
	end
	gfx.drawRect(ox, oy, s + 1, s + 1)
end

function L.draw()
	UI.big:drawText("Niveaux", 10, 4)
	local done, total = Save.countLevels()
	UI.right(UI.font, done .. " / " .. total .. " resolues", 390, 12)

	local tabW = math.floor((380 - (#PUZZLES - 1) * 4) / #PUZZLES)
	for l, lv in ipairs(PUZZLES) do
		local x, y = 10 + (l - 1) * (tabW + 4), 38
		if l == level then
			UI.pill(UI.bold, lv.name, x, y, tabW, 26)
			if focus == 0 then
				gfx.setLineWidth(2)
				gfx.drawRoundRect(x - 3, y - 3, tabW + 6, 32, 15)
				gfx.setLineWidth(1)
			end
		else
			gfx.drawRoundRect(x, y, tabW, 26, 13)
			UI.centered(UI.font, lv.name, x + tabW / 2, y + 13)
		end
	end

	local list = PUZZLES[level].list
	local ts, gap, ox, oy = 34, 6, 10, 80
	for i = 1, #list do
		local r, c = math.floor((i - 1) / COLS), (i - 1) % COLS
		local x, y = ox + c * (ts + gap), oy + r * (ts + gap)
		local key = Save.levelKey(level, i)
		if Save.isSolved(key) then
			UI.pill(UI.bold, tostring(i), x, y, ts, ts)
		else
			gfx.drawRoundRect(x, y, ts, ts, 5)
			UI.centered(UI.bold, tostring(i), x + ts / 2, y + ts / 2)
			if Save.data.progress[key] then
				UI.gray(0.5)
				gfx.fillRect(x + 4, y + ts - 7, ts - 8, 3)
				gfx.setColor(gfx.kColorBlack)
			end
		end
		if i == index and focus == 1 then
			gfx.setLineWidth(2)
			gfx.drawRoundRect(x - 3, y - 3, ts + 6, ts + 6, 7)
			gfx.setLineWidth(1)
		end
	end

	local lv = PUZZLES[level]
	local key = Save.levelKey(level, index)
	local info
	if Save.isSolved(key) then
		info = "Resolue - record " .. UI.formatTime(Save.data.solved[key])
	elseif Save.data.progress[key] then
		info = "En cours - " .. UI.formatTime(Save.data.progress[key].time)
	else
		info = "Nouvelle grille"
	end
	UI.bold:drawText("Grille " .. index .. "  (" .. lv.size .. "x" .. lv.size .. ")", 10, 166)
	UI.font:drawText(info, 10, 186)
	UI.font:drawText("Ⓐ Jouer   ✛ Choisir   Ⓑ Accueil", 10, 216)

	drawPreview(level, index, 262, 80, 128)
end
