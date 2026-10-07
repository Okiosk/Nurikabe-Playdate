-- Nurikabe pour Playdate : point d'entree, boucle principale et routage des commandes.
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/crank"

import "puzzles"
import "mosaics"
import "board"
import "common"
import "game"
import "home"
import "levels"
import "mosaic"
import "tutorial"

local pd <const> = playdate
local gfx <const> = pd.graphics

pd.display.setRefreshRate(30)

---------------------------------------------------------------- commandes

local repeatTimers = {}

local function startRepeat(name, dr, dc)
	if repeatTimers[name] then repeatTimers[name]:remove() end
	repeatTimers[name] = pd.timer.keyRepeatTimer(function()
		if App.scene.move then App.scene.move(dr, dc) end
	end)
end

local function stopRepeat(name)
	if repeatTimers[name] then
		repeatTimers[name]:remove()
		repeatTimers[name] = nil
	end
end

function pd.upButtonDown() startRepeat("up", -1, 0) end
function pd.downButtonDown() startRepeat("down", 1, 0) end
function pd.leftButtonDown() startRepeat("left", 0, -1) end
function pd.rightButtonDown() startRepeat("right", 0, 1) end
function pd.upButtonUp() stopRepeat("up") end
function pd.downButtonUp() stopRepeat("down") end
function pd.leftButtonUp() stopRepeat("left") end
function pd.rightButtonUp() stopRepeat("right") end

-- Un changement de scene pendant un appui ne doit pas transmettre le relachement a la nouvelle scene
local pressedIn = {}
function pd.AButtonDown()
	pressedIn.A = App.scene
	if App.scene.A then App.scene.A(true) end
end
function pd.AButtonUp()
	if pressedIn.A == App.scene and App.scene.A then App.scene.A(false) end
	pressedIn.A = nil
end
function pd.BButtonDown()
	pressedIn.B = App.scene
	if App.scene.B then App.scene.B(true) end
end
function pd.BButtonUp()
	if pressedIn.B == App.scene and App.scene.B then App.scene.B(false) end
	pressedIn.B = nil
end

---------------------------------------------------------------- cycle de vie

local lastTime = pd.getCurrentTimeMilliseconds()

local function persist()
	if App.name == "game" then Scenes.game.saveProgress() else Save.write() end
end

function pd.gameWillTerminate() persist() end
function pd.deviceWillSleep() persist() end
function pd.gameWillPause()
	if App.scene.pause then App.scene.pause() else persist() end
end
function pd.gameWillResume()
	lastTime = pd.getCurrentTimeMilliseconds()
	App.redraw()
end

---------------------------------------------------------------- boucle

App.go("home")

function pd.update()
	local now = pd.getCurrentTimeMilliseconds()
	local dt = now - lastTime
	lastTime = now

	pd.timer.updateTimers()

	local ticks = pd.getCrankTicks(12)
	if ticks ~= 0 and App.scene.crank then App.scene.crank(ticks) end

	if App.scene.update then App.scene.update(dt) end

	if App.dirty then
		App.dirty = false
		gfx.clear(gfx.kColorWhite)
		gfx.setColor(gfx.kColorBlack)
		App.scene.draw()
	end
end
