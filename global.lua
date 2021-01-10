require("status")
require("loadfile")

filePath = ""
alreadyRepacking = false

-- General state
KEYFRAME_LIST_GLOBAL = {}
CURRENT_TEXT_BOX = require "textbox"
CURRENT_MOUSEOVER_TARGET = ""
CURRENT_MODE = "default"
MAP_ON = false
MAP_LOCK = true
UI_FLIP = false

-- Image extraction
THREAD_POOL = {}
CURRENT_FRAMES_DIR = ""
CURRENT_FRAMES_INDEX = 1
EXTERNAL_COMMANDS_ALLOWED = true

-- God Objects
currentFilm = nil

-- File Management
FileMgr = require("file_manager")
DELIM = "\t"
FILE_NAME = "empty"
APP_NAME = "Framescop V1.5"
CURRENT_AUTHOR = ""
DECOMPRESSED_FRAMES = {}

-- Fonts
LOVEdefaultFont = love.graphics:getFont()
BigFont = love.graphics.newFont(24)

-- Images
BUTTON_SPRITE_SHEET = love.graphics.newImage("buttons.png")
BUTTON_SPRITES = {}
BUTTON_SPRITES["down"] = love.graphics.newQuad(0, 0, 15, 20, BUTTON_SPRITE_SHEET:getDimensions())
BUTTON_SPRITES["left"] = love.graphics.newQuad(16, 0, 15, 19, BUTTON_SPRITE_SHEET:getDimensions())
BUTTON_SPRITES["up"] = love.graphics.newQuad(32, 0, 15, 20, BUTTON_SPRITE_SHEET:getDimensions())
BUTTON_SPRITES["right"] = love.graphics.newQuad(48, 0, 15, 19, BUTTON_SPRITE_SHEET:getDimensions())
BUTTON_SPRITES["x"] = love.graphics.newQuad(0, 21, 20, 21, BUTTON_SPRITE_SHEET:getDimensions())
BUTTON_SPRITES["circle"] = love.graphics.newQuad(21, 21, 20, 21, BUTTON_SPRITE_SHEET:getDimensions())
BUTTON_SPRITES["triangle"] = love.graphics.newQuad(42, 21, 20, 21, BUTTON_SPRITE_SHEET:getDimensions())
BUTTON_SPRITES["square"] = love.graphics.newQuad(63, 21, 20, 21, BUTTON_SPRITE_SHEET:getDimensions())
BUTTON_SPRITES["start"] = love.graphics.newQuad(64, 0, 14, 17, BUTTON_SPRITE_SHEET:getDimensions())
BUTTON_SPRITES["select"] = love.graphics.newQuad(145, 0, 27, 17, BUTTON_SPRITE_SHEET:getDimensions())

function drawButtonGraphic(buttonName, x, y, relx, rely, scale)
	love.graphics.draw(BUTTON_SPRITE_SHEET, BUTTON_SPRITES[buttonName], x, y, 0, scale, scale, relx, rely)
end

-- Window setup
function updateWindowTitle()
    local easterEgg = {
		'"So how does it become giftstrot"',
		'"Giftcrop Protip: An"',
		'"discord is a software"',
		'"imagine you put in a face and it says" "kris in the real"',
		'"i like the idea that belle h"',
		'"the awoglet who what when where why and how"',
		'"p3d shirt would be just a recreation of a shirt but made inaccurately"',
		'"we need more sd matadors" "no"',
		'"dynamic smug cheese"',
		'"we hereby declare your work zone lead inaccurate"',
		'"you guys like ntsc" "james when did you become a drug dealer"',
		'"what is even happening" "I am recreating tony" "oh no"'
    }
    local title = easterEgg[love.math.random(1, #easterEgg)]
    love.window.setTitle("Framescop - " .. title .. " - " .. FILE_NAME)
end


--- ERROR HANDLER
local utf8 = require("utf8")
 
local function error_printer(msg, layer)
	print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end
function love.errorhandler(msg)
    local savename = 'PANICSV-'..love.math.random(10000)
    FileMgr.saveAs(savename)

    -- LOVE2D default error handler
    msg = tostring(msg)
 
	error_printer(msg, 2)
 
	if not love.window or not love.graphics or not love.event then
		return
	end
 
	if not love.graphics.isCreated() or not love.window.isOpen() then
		local success, status = pcall(love.window.setMode, 800, 600)
		if not success or not status then
			return
		end
	end
 
	-- Reset state.
	if love.mouse then
		love.mouse.setVisible(true)
		love.mouse.setGrabbed(false)
		love.mouse.setRelativeMode(false)
		if love.mouse.isCursorSupported() then
			love.mouse.setCursor()
		end
	end
	if love.joystick then
		-- Stop all joystick vibrations.
		for i,v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration()
		end
	end
	if love.audio then love.audio.stop() end
 
	love.graphics.reset()
	local font = love.graphics.setNewFont(14)
 
	love.graphics.setColor(1, 1, 1, 1)
 
	local trace = debug.traceback()
 
	love.graphics.origin()
 
	local sanitizedmsg = {}
	for char in msg:gmatch(utf8.charpattern) do
		table.insert(sanitizedmsg, char)
	end
	sanitizedmsg = table.concat(sanitizedmsg)
 
	local err = {}
 
	table.insert(err, "Error\n")
	table.insert(err, sanitizedmsg)
 
	if #sanitizedmsg ~= #msg then
		table.insert(err, "Invalid UTF-8 string in error message.")
	end
 
	table.insert(err, "\n")
 
	for l in trace:gmatch("(.-)\n") do
		if not l:match("boot.lua") then
			l = l:gsub("stack traceback:", "Traceback\n")
			table.insert(err, l)
		end
	end
 
	local p = table.concat(err, "\n")
 
    p = p .. '\n\nPanic save saved in your AppData folder as ' .. savename

	p = p:gsub("\t", "")
	p = p:gsub("%[string \"(.-)\"%]", "%1")
 
	local function draw()
		local pos = 70
		love.graphics.clear(89/255, 157/255, 220/255)
		love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos)
		love.graphics.present()
	end
 
	local fullErrorText = p
	local function copyToClipboard()
		if not love.system then return end
		love.system.setClipboardText(fullErrorText)
		p = p .. "\nCopied to clipboard!"
		draw()
    end
 
	if love.system then
		p = p .. "\n\nPress Ctrl+C or tap to copy this error"
	end
 
	return function()
		love.event.pump()
 
		for e, a, b, c in love.event.poll() do
			if e == "quit" then
				return 1
			elseif e == "keypressed" and a == "escape" then
				return 1
			elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
				copyToClipboard()
			elseif e == "touchpressed" then
				local name = love.window.getTitle()
				if #name == 0 or name == "Untitled" then name = "Game" end
				local buttons = {"OK", "Cancel"}
				if love.system then
					buttons[3] = "Copy to clipboard"
				end
				local pressed = love.window.showMessageBox("Quit "..name.."?", "", buttons)
				if pressed == 1 then
					return 1
				elseif pressed == 3 then
					copyToClipboard()
				end
			end
		end
 
		draw()
 
		if love.timer then
			love.timer.sleep(0.1)
		end
	end
end
