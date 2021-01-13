WorkingDirectoryBinaries = nil
-- Loads all binaries in working directory
function loadWorkingDirectory()
    if WorkingDirectoryBinaries then
        return WorkingDirectoryBinaries
    else
        WorkingDirectoryBinaries = {}
    end

    local binaries = love.filesystem.getDirectoryItems("framedata")

    for i, folderName in ipairs(binaries) do
        local path = "framedata/" .. folderName
        if love.filesystem.getInfo(path).type == "directory" then
            local files = love.filesystem.getDirectoryItems(path)
            for j, filename in ipairs(files) do
                if filename == "0.mp4" then
                    obj = {}
                    obj.path = path
                    obj.filename = folderName
                    local lines = love.filesystem.read(path .. "/" .. filename):split("\n")
                    obj.niceTitle = lines[1]
                    obj.fps = tonumber(lines[2])
                    WorkingDirectoryBinaries[#WorkingDirectoryBinaries + 1] = obj
                elseif filename == "1.png" then
                    local output = love.filesystem.getSaveDirectory() .. "\\framedata\\" .. folderName
                    local command = '.\\frame_extractor.bat a "' .. folderName .. '"'
                    local thread = love.thread.newThread("ffmpeg_bootstrap.lua")
                    THREAD_POOL[#THREAD_POOL + 1] = thread
                    thread:start(command, output)

                    obj = {}
                    obj.path = path
                    obj.filename = folderName
                    local lines = love.filesystem.read(path .. "/" .. filename):split("\n")
                    obj.niceTitle = lines[1]
                    obj.fps = tonumber(lines[2])
                    WorkingDirectoryBinaries[#WorkingDirectoryBinaries + 1] = obj
                end
            end
        end
    end

    return WorkingDirectoryBinaries
end
