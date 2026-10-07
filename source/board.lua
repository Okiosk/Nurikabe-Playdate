-- Logique pure d'une grille de Nurikabe (aucune dependance au SDK Playdate).

EMPTY, BLACK, DOT = 0, 1, 2

Board = {}
Board.__index = Board

-- Indices : '1'..'9', puis 'a' = 10 ... 'z' = 35, puis 'A' = 36 ... 'Z' = 61
local DIGITS <const> = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
function Board.clueValue(ch)
	if ch == "." then return nil end
	local k = DIGITS:find(ch, 1, true)
	return k and (k - 1) or nil
end

function Board.new(puzzle)
	local n = #puzzle.grid
	local b = setmetatable({ n = n, clue = {}, cell = {}, sol = {}, undoStack = {}, redoStack = {} }, Board)
	for r = 1, n do
		local row, srow = puzzle.grid[r], puzzle.sol[r]
		for c = 1, n do
			local i = (r - 1) * n + c
			b.clue[i] = Board.clueValue(row:sub(c, c))
			b.cell[i] = EMPTY
			b.sol[i] = srow:sub(c, c) == "#"
		end
	end
	b:analyze()
	return b
end

function Board:index(r, c) return (r - 1) * self.n + c end
function Board:rc(i) return math.floor((i - 1) / self.n) + 1, (i - 1) % self.n + 1 end

function Board:neighbors(i)
	local n = self.n
	local r, c = self:rc(i)
	local out = {}
	if r > 1 then out[#out + 1] = i - n end
	if r < n then out[#out + 1] = i + n end
	if c > 1 then out[#out + 1] = i - 1 end
	if c < n then out[#out + 1] = i + 1 end
	return out
end

---------------------------------------------------------------- edition / annulation

function Board:beginStroke() self.stroke = {} end

-- Modifie une case ; renvoie true si quelque chose a change.
function Board:setCell(i, v)
	if self.clue[i] or self.cell[i] == v then return false end
	if self.stroke then
		self.stroke[#self.stroke + 1] = { i, self.cell[i], v }
	end
	self.cell[i] = v
	return true
end

function Board:endStroke()
	if self.stroke and #self.stroke > 0 then
		self.undoStack[#self.undoStack + 1] = self.stroke
		self.redoStack = {}
	end
	self.stroke = nil
	self:analyze()
end

function Board:undo()
	local s = table.remove(self.undoStack)
	if not s then return false end
	for k = #s, 1, -1 do self.cell[s[k][1]] = s[k][2] end
	self.redoStack[#self.redoStack + 1] = s
	self:analyze()
	return true
end

function Board:redo()
	local s = table.remove(self.redoStack)
	if not s then return false end
	for k = 1, #s do self.cell[s[k][1]] = s[k][3] end
	self.undoStack[#self.undoStack + 1] = s
	self:analyze()
	return true
end

function Board:reset()
	self:beginStroke()
	for i = 1, self.n * self.n do self:setCell(i, EMPTY) end
	self:endStroke()
end

---------------------------------------------------------------- sauvegarde

function Board:serialize()
	local t = {}
	for i = 1, self.n * self.n do t[i] = tostring(self.cell[i]) end
	return table.concat(t)
end

function Board:load(str)
	if type(str) ~= "string" or #str ~= self.n * self.n then return end
	for i = 1, #str do
		local v = tonumber(str:sub(i, i))
		if not self.clue[i] and (v == EMPTY or v == BLACK or v == DOT) then self.cell[i] = v end
	end
	self:analyze()
end

---------------------------------------------------------------- analyse des erreurs

-- Calcule self.pool (coin haut-gauche des blocs 2x2 noirs),
-- self.badClue (indices en erreur) et self.badDot (points isoles impossibles).
function Board:analyze()
	local n, cell, clue = self.n, self.cell, self.clue
	self.pool, self.badClue, self.badDot = {}, {}, {}

	for r = 1, n - 1 do
		for c = 1, n - 1 do
			local i = (r - 1) * n + c
			if cell[i] == BLACK and cell[i + 1] == BLACK and cell[i + n] == BLACK and cell[i + n + 1] == BLACK then
				self.pool[i] = true
			end
		end
	end

	-- composantes de cases "blanches confirmees" (indices + points)
	local seen = {}
	for s = 1, n * n do
		if not seen[s] and (clue[s] or cell[s] == DOT) then
			local comp, clues, closed = { s }, {}, true
			seen[s] = true
			local k = 1
			while k <= #comp do
				local i = comp[k]
				if clue[i] then clues[#clues + 1] = i end
				for _, j in ipairs(self:neighbors(i)) do
					if clue[j] or cell[j] == DOT then
						if not seen[j] then
							seen[j] = true
							comp[#comp + 1] = j
						end
					elseif cell[j] == EMPTY then
						closed = false
					end
				end
				k = k + 1
			end
			local size = #comp
			if #clues > 1 then
				for _, i in ipairs(clues) do self.badClue[i] = true end
			elseif #clues == 1 then
				local v = clue[clues[1]]
				if size > v or (closed and size < v) then self.badClue[clues[1]] = true end
			elseif closed then
				for _, i in ipairs(comp) do self.badDot[i] = true end
			end
		end
	end
end

function Board:hasErrors()
	return next(self.pool) ~= nil or next(self.badClue) ~= nil or next(self.badDot) ~= nil
end

---------------------------------------------------------------- victoire

-- Une grille est resolue si, en considerant toute case non noire comme blanche,
-- les regles du Nurikabe sont respectees.
function Board:isSolved()
	local n, cell, clue = self.n, self.cell, self.clue
	if next(self.pool) then return false end

	local seen, blackCount, firstBlack = {}, 0, nil
	for i = 1, n * n do
		if cell[i] == BLACK then
			blackCount = blackCount + 1
			firstBlack = firstBlack or i
		end
	end
	if blackCount == 0 then return false end

	-- mer connexe
	local stack, reached = { firstBlack }, 1
	seen[firstBlack] = true
	while #stack > 0 do
		local i = table.remove(stack)
		for _, j in ipairs(self:neighbors(i)) do
			if cell[j] == BLACK and not seen[j] then
				seen[j] = true
				reached = reached + 1
				stack[#stack + 1] = j
			end
		end
	end
	if reached ~= blackCount then return false end

	-- iles : un seul indice, taille exacte
	for s = 1, n * n do
		if cell[s] ~= BLACK and not seen[s] then
			local comp, clueVal, clueCount = { s }, nil, 0
			seen[s] = true
			local k = 1
			while k <= #comp do
				local i = comp[k]
				if clue[i] then
					clueCount = clueCount + 1
					clueVal = clue[i]
				end
				for _, j in ipairs(self:neighbors(i)) do
					if cell[j] ~= BLACK and not seen[j] then
						seen[j] = true
						comp[#comp + 1] = j
					end
				end
				k = k + 1
			end
			if clueCount ~= 1 or #comp ~= clueVal then return false end
		end
	end
	return true
end

-- Remplit de points les cases blanches restantes (pour l'affichage final).
function Board:fillDots()
	for i = 1, self.n * self.n do
		if not self.clue[i] and self.cell[i] == EMPTY then self.cell[i] = DOT end
	end
	self:analyze()
end

---------------------------------------------------------------- indice

-- Corrige une case (la plus proche du curseur) en s'appuyant sur la solution.
-- Priorite : cases fausses, puis cases noires manquantes, puis points manquants.
-- Renvoie l'index corrige ou nil.
function Board:hint(cursor)
	local cr, cc = self:rc(cursor)
	local function pick(test)
		local best, bestD = nil, math.huge
		for i = 1, self.n * self.n do
			if not self.clue[i] and test(i) then
				local r, c = self:rc(i)
				local d = math.abs(r - cr) + math.abs(c - cc)
				if d < bestD then best, bestD = i, d end
			end
		end
		return best
	end
	local cell, sol = self.cell, self.sol
	local i = pick(function(k) return (cell[k] == BLACK and not sol[k]) or (cell[k] == DOT and sol[k]) end)
		or pick(function(k) return sol[k] and cell[k] ~= BLACK end)
		or pick(function(k) return not sol[k] and cell[k] == EMPTY end)
	if not i then return nil end
	self:beginStroke()
	self:setCell(i, sol[i] and BLACK or DOT)
	self:endStroke()
	return i
end
