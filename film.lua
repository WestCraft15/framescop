-- We're calling this "Film" because it's a series of static images played back
-- to make it look like it's a contiguous video.

require("stringutil")
local Keyframe = require("keyframe")
local Timeline = require("timeline")

local Film = {}
Film.__index = Film

Film.new = function(dirPath)
    local self = {}
    setmetatable(self, Film)

    local split = dirPath:split("/")
    FILE_NAME = split[#split]
    FileMgr.trackPath = FILE_NAME .. ".tsv"
    updateWindowTitle()
    
    self.playhead = 1
    
    self.allFrames = 0
    self.offsets = love.filesystem.read(dirPath .. "/offsets.txt"):split("\n")
    for i = 2, #self.offsets do
        self.allFrames = self.allFrames + tonumber(self.offsets[i])
    end

    if love.filesystem.exists("framedata/" .. FILE_NAME .. "/loadedFrames.txt") then
        self:h_removeFrames()
    end

    self.title = dirPath
    self.fps = 30
    self.path = dirPath
    self.totalFrames = 0
    self.framesInMemory = 0
    self.cachedFrontier = 0
    self.playRealTime = false
    self.realTime = 0
    self.timeline = Timeline.new(self)
    self.currentChunk = 0
    self.chunkSize = 15
    
    self.data = {}
    self:h_decompress(1)
    self:h_loadAt(1, self.chunkSize - 1)
    
    FileMgr.init(self)
    FileMgr.load(self)
    
    return self
end

Film.update = function(self, dt)
    -- Handle realtime playback
    if self.playRealTime then
        self.realTime = self.realTime + dt * self.fps
        self.playhead = math.floor(self.realTime) + 1
        if self:h_boundedFromPlayhead(0) ~= self.playhead then
            self.playhead = self:h_boundedFromPlayhead(0)
            self.playRealTime = false
        end
    else
        self.realTime = self.playhead
        self:h_clearData()
    end
    
    if math.floor(self.playhead / self.chunkSize) ~= self.currentChunk then
        self.currentChunk = math.floor(self.playhead / self.chunkSize)
        self:h_loadAt(((self.currentChunk - 2) * self.chunkSize) + 1, self.chunkSize * 3)
        self:h_clearData()
    end
    
    self.timeline:update(dt)
end

Film.draw = function(self)
    local frame = self:getFrameImage(self.playhead)
    if frame then
        local scalex = love.graphics.getWidth() / frame:getWidth()
        local scaley = love.graphics.getHeight() / frame:getHeight()
        love.graphics.draw(frame, 0, 0, 0, scalex, scaley)
        
        self.timeline:draw()
    end
end

Film.getFrameImage = function(self, index)
    if self.data[index] then
        return self.data[index]
    end
    
    if self:h_loadAt(index, 14) then
        return self.data[index]
    end
end

Film.movePlayheadTo = function(self, index)
    if index < 1 then
        self.playhead = 1
    elseif index > self.totalFrames then
        self.playhead = self.totalFrames
    else
        self.playhead = index
    end
end

Film.status = function(self)
    return "time: " .. self:timeString() .. "\t" .. self.framesInMemory .. " images in memory" .. "\t"
end

Film.timeString = function(self, x)
    if x == nil then
        x = self.playhead
    end
    local seconds = math.floor((x - 1) / self.fps)
    return string.format("%02d", math.floor(seconds / 60)) ..
    ":" .. string.format("%02d", seconds % 60) .. ";" .. string.format("%02d", (x - 1) % self.fps)
end

Film.timeStringToFrames = function(self, timeString)
    if timeString == nil then
        timeString = self:timeString()
    end
    
    local tsSplitOnColon = timeString:split(":")
    local minutes = tsSplitOnColon[1]
    local seconds = tsSplitOnColon[2]:split(";")[1] + minutes * 60
    local video_frame = tonumber(timeString:split(";")[2])
    
    local frames = seconds * self.fps + video_frame + 1
    print("read " .. timeString .. " as " .. frames)
    return frames
end

Film.getTrackPath = function(self)
    return FileMgr.trackPath
end

--- HELPER FUNCTIONS BELOW THIS POINT ---

-- Helper function to keep the constructor looking clean
Film.h_loadAt = function(self, location, size)
    if location < 1 then
        location = 1
    end
    
    if location + size > self.totalFrames then
        size = self.totalFrames - location
    end
    
    local loadedSomething = false
    
    for i = location, location + size do
        if not self.data[i] then
            if love.filesystem.exists(self.path .. "/" .. i .. ".png") then
                self.framesInMemory = self.framesInMemory + 1
                self.data[i] = love.graphics.newImage(self.path .. "/" .. i .. ".png")
                loadedSomething = true
            else
                local findChunk = 0
                for j = 2, #self.offsets do
                    findChunk = findChunk + tonumber(self.offsets[j])
                    if i < findChunk then
                        self:h_decompress(j - 1)
                        break
                    end
                end
            end
        end
    end
    
    return loadedSomething
end

Film.h_eraseAt = function(self, location, size)
    if location < 1 then
        location = 1
    end
    
    if location + size > self.totalFrames then
        size = self.totalFrames - location
    end
    
    for i = location, location + size do
        if self.data[i] then
            -- Delete from table, hand to garbage collector
            self.framesInMemory = self.framesInMemory - 1
            self.data[i]:release()
            self.data[i] = nil
        end
    end
end

Film.h_decompress = function(self, chunk)
    local timeToExtract = chunk - 1
    
    local startOffset = 1
    local endOffset = 0
    for i = 2, chunk + 1 do
        if i ~= chunk + 1 then
            startOffset = startOffset + tonumber(self.offsets[i])
            endOffset = endOffset + tonumber(self.offsets[i])
        else
            endOffset = endOffset + tonumber(self.offsets[i])
        end
    end
    
    local output = love.filesystem.getSaveDirectory() .. "\\framedata\\" .. FILE_NAME
    
    local command = '.\\ffmpeg -i "' .. output .. '\\' .. timeToExtract .. '.mp4" -start_number ' .. startOffset .. ' -r 30 -s 320x240 "' .. output .. '\\%d.png"'
    local thread = love.thread.newThread("ffmpeg_bootstrap.lua")
    THREAD_POOL[#THREAD_POOL + 1] = thread
    thread:start(command, output)
    local fullList = ""
    for j = startOffset, endOffset do
        table.insert(DECOMPRESSED_FRAMES, j)
        fullList = fullList .. j .. "\n"
    end
    if love.filesystem.exists("framedata/" .. FILE_NAME .. "/loadedFrames.txt") then
        love.filesystem.append("framedata/" .. FILE_NAME .. "/loadedFrames.txt", fullList)
    else
        love.filesystem.write("framedata/" .. FILE_NAME .. "/loadedFrames.txt", fullList)
    end
    for i = 1, 2, 0 do
        if #love.filesystem.getDirectoryItems(self.path) == #DECOMPRESSED_FRAMES + #self.offsets + 1 then
            self.totalFrames = self.allFrames
            break
        end
    end
end

-- Hard reset on memory usage. Throws everything to the garbage collector except for
-- the most nearby stuff
Film.h_clearData = function(self)
    for i = 0, self.totalFrames do
        if i < (((math.floor(self.playhead / self.chunkSize) - 2) * self.chunkSize) + 1) or i > (((math.floor(self.playhead / self.chunkSize) + 1) * self.chunkSize)) then
            if self.data[i] then
                self.framesInMemory = self.framesInMemory - 1
                self.data[i]:release()
                self.data[i] = nil
            end
        end
    end
end

-- If this offset from playhead is in bounds, return that.
-- Otherwise return bound we're up against
Film.h_boundedFromPlayhead = function(self, offset)
    local val = self.playhead + offset
    if val < 1 then
        val = 1
    end
    if val > self.totalFrames then
        val = self.totalFrames
    end
    return val
end

Film.h_removeFrames = function(self)
    local framesToDelete = love.filesystem.read("framedata/" .. FILE_NAME .. "/loadedFrames.txt"):split("\n")
    for i = 1, #framesToDelete do
        if love.filesystem.exists("framedata/" .. FILE_NAME .. "/" .. framesToDelete[i] .. ".png") then
            love.filesystem.remove("framedata/" .. FILE_NAME .. "/" .. framesToDelete[i] .. ".png")
        end
    end
    love.filesystem.remove("framedata/" .. FILE_NAME .. "/loadedFrames.txt")
end

return Film
