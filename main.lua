require("global")
require("input")
require("colors")
require("map")
require("film")

local Button = require("button")
local ctlStateEnum = require("controller_state")
local Film = require("film")
local Keyframe = require("keyframe")
local FileManager = require("file_manager")

local videosOffset = 0
local videosOffsetAdd = 0
local mouseWait = 0

require("tests.test_all")

iconData = love.image.newImageData("icon.png")
love.window.setIcon(iconData)

function love.load(arg)
    -- Setup window
    love.window.updateMode(800, 600, {resizable = false})
    updateWindowTitle()

    -- Build working dir cache
    loadWorkingDirectory()

    local author = love.filesystem.read("author")
    if author then
        CURRENT_AUTHOR = author
    end
end

function love.quit()
    if FILE_NAME then
        for i = 1, #DECOMPRESSED_FRAMES do
            love.filesystem.remove("framedata/" .. FILE_NAME .. "/" .. DECOMPRESSED_FRAMES[i] .. ".png")
        end
        love.filesystem.remove("framedata/" .. FILE_NAME .. "/loadedFrames.txt")
    end
end

function love.update(dt)
    CURRENT_MOUSEOVER_TARGET = ""
    CURRENT_TEXT_BOX:update(dt)

    if currentFilm then
        currentFilm:update(dt)
    end

    Keyframe.editMode = 0
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        Keyframe.editMode = 1
    elseif love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt") then
        Keyframe.editMode = 2
    end -- This way if you're pressing both ctrl & alt you don't get unexpected behaviour

    updateStatusText(dt)
end

function love.draw()
    love.graphics.setFont(BigFont)

    if not currentFilm then
        if CURRENT_AUTHOR == "" then
            CURRENT_TEXT_BOX.on = true
            love.graphics.setFont(BigFont)
            love.graphics.print(
                "Type your username so you can be credited.\nLeave blank for 'anonymous'\n\nName: " ..
                    CURRENT_TEXT_BOX.body .. CURRENT_TEXT_BOX.cursor
            )

            if CURRENT_TEXT_BOX.submitted then
                CURRENT_AUTHOR = CURRENT_TEXT_BOX.clear()
                if CURRENT_AUTHOR == "" then
                    CURRENT_AUTHOR = "anonymous"
                end
                love.filesystem.write("author", CURRENT_AUTHOR)
            end

            return
        end

        local binaries = loadWorkingDirectory()
        if #binaries == 0 then
            love.filesystem.createDirectory("framedata")
            love.graphics.print("No videos found. Please drag a\nvideo onto the included .bat file.\n\nYou will need to restart Framescop to see the new video.")
        end

        -- File select menu
        local mx, my = love.mouse.getPosition()
        for i, obj in ipairs(binaries) do
            if i - videosOffset > 7 then
                love.graphics.setFont(BigFont)
                local x = 550 + love.graphics.getFont():getWidth("Delete") - love.graphics.getFont():getWidth("Next")
                local y = 30
                if
                mx > x + 97 and mx < x + love.graphics.getFont():getWidth("Next") + 108 and my > y + (i - 1 - videosOffset) * 60 and
                my < y + (i - 1 - videosOffset) * 60 + love.graphics.getFont():getHeight()
                then
                    love.graphics.setColor(0, 0, 1)
                    love.graphics.rectangle(
                        "fill",
                        x + 97,
                        y + (i - 1 - videosOffset) * 60,
                        love.graphics.getFont():getWidth("Next") + 8,
                        love.graphics.getFont():getHeight()
                    )
                    if love.mouse.isDown(1) and mouseWait == 0 then
                        videosOffsetAdd = 7
                        mouseWait = 1
                    elseif not love.mouse.isDown(1) then
                        mouseWait = 0
                    end
                end
                love.graphics.setColor(white())
                love.graphics.rectangle(
                    "line",
                    x + 97,
                    y + (i - 1 - videosOffset) * 60,
                    love.graphics.getFont():getWidth("Next") + 8,
                    love.graphics.getFont():getHeight()
                )
                
                love.graphics.setColor(white())
                love.graphics.print("Next", x + 100, y + (i - 1 - videosOffset) * 60)
                break
            elseif binaries[i] ~= "empty" and i - videosOffset > 0 then
                if love.keyboard.isDown(i - videosOffset) then
                    love.graphics.setColor(0.5, 0.5, 1)
                    currentFilm = Film.new(obj.path)
                end
                love.graphics.setFont(BigFont)
                local x = 550
                local textX = 60
                local y = 30
                local buttonText = obj.filename
                if
                mx > x - 3 and mx < x + love.graphics.getFont():getWidth("Start") and my > y + (i - 1 - videosOffset) * 60 and
                my < y + (i - 1 - videosOffset) * 60 + love.graphics.getFont():getHeight()
                then
                    love.graphics.setColor(0, 0, 1)
                    love.graphics.rectangle(
                        "fill",
                        x - 3,
                        y + (i - 1 - videosOffset) * 60,
                        love.graphics.getFont():getWidth("Start") + 8,
                        love.graphics.getFont():getHeight()
                    )
                    if love.mouse.isDown(1) then
                        currentFilm = Film.new(obj.path)
                    end
                end
                love.graphics.setColor(white())
                love.graphics.rectangle(
                    "line",
                    x - 3,
                    y + (i - 1 - videosOffset) * 60,
                    love.graphics.getFont():getWidth("Start") + 8,
                    love.graphics.getFont():getHeight()
                )
                
                if
                mx > x + 97 and mx < x + love.graphics.getFont():getWidth("Delete") + 108 and my > y + (i - 1 - videosOffset) * 60 and
                my < y + (i - 1 - videosOffset) * 60 + love.graphics.getFont():getHeight()
                then
                    love.graphics.setColor(0, 0, 1)
                    love.graphics.rectangle(
                        "fill",
                        x + 97,
                        y + (i - 1 - videosOffset) * 60,
                        love.graphics.getFont():getWidth("Delete") + 8,
                        love.graphics.getFont():getHeight()
                    )
                    if love.mouse.isDown(1) and love.mouse.isDown(2) then
                        local function recursivelyDelete( item )
                            if love.filesystem.getInfo(item , "directory") then
                                for _, child in pairs(love.filesystem.getDirectoryItems(item)) do
                                    recursivelyDelete(item .. '/' .. child)
                                    love.filesystem.remove(item .. '/' .. child)
                                end
                            elseif love.filesystem.getInfo(item) then
                                love.filesystem.remove(item)
                            end
                            love.filesystem.remove(item)
                        end
                        recursivelyDelete("framedata/" .. obj.filename)
                        binaries[i] = "empty"
                    end
                end
                love.graphics.setColor(white())
                love.graphics.rectangle(
                    "line",
                    x + 97,
                    y + (i - 1 - videosOffset) * 60,
                    love.graphics.getFont():getWidth("Delete") + 8,
                    love.graphics.getFont():getHeight()
                )
                
                love.graphics.setColor(white())
                love.graphics.print(buttonText, textX, y + (i - 1 - videosOffset) * 60)
                love.graphics.print("Start", x, y + (i - 1 - videosOffset) * 60)
                love.graphics.print("Delete", x + 100, y + (i - 1 - videosOffset) * 60)
            end
        end

        if videosOffset > 0 then
            love.graphics.setFont(BigFont)
            local x = 60
            local y = 30
            if
            mx > x - 3 and mx < x + love.graphics.getFont():getWidth("Back") and my > y + 7 * 60 and
            my < y + 7 * 60 + love.graphics.getFont():getHeight()
            then
                love.graphics.setColor(0, 0, 1)
                love.graphics.rectangle(
                    "fill",
                    x - 3,
                    y + 7 * 60,
                    love.graphics.getFont():getWidth("Back") + 8,
                    love.graphics.getFont():getHeight()
                )
                if love.mouse.isDown(1) and mouseWait == 0 then
                    videosOffsetAdd = -7
                    mouseWait = 1
                elseif not love.mouse.isDown(1) then
                    mouseWait = 0
                end
            end
            love.graphics.setColor(white())
            love.graphics.rectangle(
                "line",
                x - 3,
                y + 7 * 60,
                love.graphics.getFont():getWidth("Back") + 8,
                love.graphics.getFont():getHeight()
            )
            
            love.graphics.setColor(white())
            love.graphics.print("Back", x, y + 7 * 60)
        end
        
        love.graphics.setFont(BigFont)
        local x = 650 + love.graphics.getFont():getWidth("Delete") - love.graphics.getFont():getWidth("Show Saves")
        local y = 30
        if
        mx > x - 3 and mx < x + love.graphics.getFont():getWidth("Show Saves") and my > y + 8 * 60 and
        my < y + 8 * 60 + love.graphics.getFont():getHeight()
        then
            love.graphics.setColor(0, 0, 1)
            love.graphics.rectangle(
                "fill",
                x - 3,
                y + 8 * 60,
                love.graphics.getFont():getWidth("Show Saves") + 8,
                love.graphics.getFont():getHeight()
            )
            if love.mouse.isDown(1) then
                love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
            end
        end
        love.graphics.setColor(white())
        love.graphics.rectangle(
            "line",
            x - 3,
            y + 8 * 60,
            love.graphics.getFont():getWidth("Show Saves") + 8,
            love.graphics.getFont():getHeight()
        )

        love.graphics.setColor(white())
        love.graphics.print("Show Saves", x, y + 8 * 60)

        love.graphics.setFont(BigFont)
        x = 60
        if
            mx > x - 3 and mx < x + love.graphics.getFont():getWidth("Change Username") and my > y + 8 * 60 and
                my < y + 8 * 60 + love.graphics.getFont():getHeight()
        then
            love.graphics.setColor(0, 0, 1)
            love.graphics.rectangle(
                "fill",
                x - 3,
                y + 8 * 60,
                love.graphics.getFont():getWidth("Change Username") + 8,
                love.graphics.getFont():getHeight()
            )
            if love.mouse.isDown(1) then
                CURRENT_AUTHOR = ""
            end
        end
        love.graphics.setColor(white())
        love.graphics.rectangle(
            "line",
            x - 3,
            y + 8 * 60,
            love.graphics.getFont():getWidth("Change Username") + 8,
            love.graphics.getFont():getHeight()
        )

        love.graphics.setColor(white())
        love.graphics.print("Change Username", x, y + 8 * 60)

        videosOffset = videosOffset + videosOffsetAdd
        videosOffsetAdd = 0
    end

    if currentFilm then
        currentFilm:draw()
        Keyframe.drawUI(currentFilm)

        love.graphics.print(currentFilm:status(), 4, love.graphics.getHeight() - 48, 0)

        local rootx = 128 + 32 + 8 + 2

        -- Keyframe timeline ticker pane
        local sizeOfBuffer = 15
        for i = -sizeOfBuffer, sizeOfBuffer do
            local width = 8
            local height = 16
            local x = rootx + width * i
            local y = love.graphics.getHeight() - 64 - 32 - 6

            if UI_FLIP then
                y = 64 + 32
            end

            if i == 0 then
                y = y - 3
                height = height + 5
            end

            love.graphics.setColor(keyframeTickerBGColor())
            if (currentFilm.playhead + i) % width == 0 then
                love.graphics.setColor(keyframeTickerBGSecondaryColor())
            end

            if Keyframe.list[currentFilm.playhead + i] then
                love.graphics.setColor(keyframeTickerCurrentFrameColor())
            end

            if currentFilm.playhead + i < 1 or currentFilm.playhead + i > currentFilm.totalFrames then
                love.graphics.setColor(darkgray())
            end

            love.graphics.rectangle("fill", x, y, width, height)
            love.graphics.setColor(black())
            love.graphics.rectangle("line", x, y, width, height)
            love.graphics.setColor(white())
        end

        love.graphics.setFont(BigFont)
        love.graphics.setColor(uiBackgroundColor())
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 32)
        love.graphics.setColor(white())
        love.graphics.print(StatusText)

        if FileMgr.trackPath then
            local textWidth = love.graphics.getFont():getWidth(FileMgr.trackPath)
            local textHeight = love.graphics.getFont():getHeight()
            local textX = love.graphics.getWidth() - textWidth
            love.graphics.print(FileMgr.trackPath, textX, 0)
        end

        if CURRENT_MODE == "notes" then
            love.graphics.setColor(notesBackgroundColor())
            love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
            love.graphics.setColor(white())
            printst("") -- clear the print status header
            love.graphics.print(
                "Notes at " .. currentFilm:timeString() .. ":\n" .. CURRENT_TEXT_BOX.body .. CURRENT_TEXT_BOX.cursor
            )
        end

        if CURRENT_MODE == "default" then
            local playPause = "Play"
            local uiFlip = "^"
            if UI_FLIP then
                uiFlip = "v"
            end
            if currentFilm.playRealTime then
                playPause = "Pause"
            end
            local buttonx = 16
            local buttony = love.graphics.getHeight() - 80

            if UI_FLIP then
                buttony = 32 + 16
            end

            Button.normal(">", buttonx + 192, buttony, 64, 32, "stepRight")
            Button.normal("<", buttonx + 64, buttony, 64, 32, "stepLeft")
            Button.normal(playPause, buttonx + 128, buttony, 64, 32, "toggleRealtimePlayback")
            Button.normal(">>", buttonx + 256, buttony, 64, 32, "jumpRight")
            Button.normal("<<", buttonx, buttony, 64, 32, "jumpLeft")
            Button.normal("Map", buttonx + 256 + 64, buttony, 32, 32, "toggleMap")
            Button.normal(uiFlip, buttonx + 256 + 128 + 64 + 32 + 16, buttony, 16, 32, "toggleUIFlip")
        end
    end

    if MAP_ON then
        Map.draw()
    end
end
