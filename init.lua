-- Privacy Shield: hide everything except iTerm2, taunt the creeper on screen 2.
-- Hotkey: Control + Option + Command + H

local MODS = { "ctrl", "alt", "cmd" }
local KEY  = "H"
local KEEP_APP = "iTerm2"

local MESSAGE = "남의 모니터 뭐가 그래 재밌어보이노 그만봐라"
local EMOJI   = "👀"

-- Drop image files into ./images next to this script. Animated GIFs animate
-- (rendered via WKWebView). If the folder is empty, the emoji is shown.
local IMAGES_DIR = "images"

local MIME = {
    png  = "image/png",
    jpg  = "image/jpeg",
    jpeg = "image/jpeg",
    gif  = "image/gif",
    heic = "image/heic",
    bmp  = "image/bmp",
    webp = "image/webp",
}

local state = {
    active      = false,
    overlay     = nil,
    hiddenApps  = {},
    previousApp = nil,
}

local function scriptDir()
    local info = debug.getinfo(1, "S").source:sub(2)
    return info:match("(.*/)") or "./"
end

local function loadImages()
    local dir = scriptDir() .. IMAGES_DIR
    local files = {}
    if not hs.fs.attributes(dir) then return files end
    for file in hs.fs.dir(dir) do
        local ext = file:lower():match("%.(%w+)$")
        if ext and MIME[ext] then
            table.insert(files, { path = dir .. "/" .. file, ext = ext })
        end
    end
    table.sort(files, function(a, b) return a.path < b.path end)
    return files
end

local function fileToDataURI(entry)
    local f = io.open(entry.path, "rb")
    if not f then return nil end
    local data = f:read("*all")
    f:close()
    return "data:" .. MIME[entry.ext] .. ";base64," .. hs.base64.encode(data)
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

-- Lay out N images on a grid so they don't overlap. Each cell gets a bit of
-- random size + position jitter so it still feels scattered.
local function scatter(frame, images)
    local n = #images
    if n == 0 then return {} end

    local aspect = frame.w / frame.h
    local cols = math.max(1, math.ceil(math.sqrt(n * aspect)))
    local rows = math.max(1, math.ceil(n / cols))

    local cellW = 100 / cols
    local cellH = 100 / rows

    local cells = {}
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            table.insert(cells, { row = r, col = c })
        end
    end
    shuffle(cells)

    local placed = {}
    for i, entry in ipairs(images) do
        local cell = cells[i]
        local sizeRatio = 0.72 + math.random() * 0.20  -- 72–92% of cell
        local imgW = cellW * sizeRatio
        local imgH = cellH * sizeRatio
        local x = cell.col * cellW + (cellW - imgW) * math.random()
        local y = cell.row * cellH + (cellH - imgH) * math.random()
        placed[i] = {
            entry = entry,
            x = x, y = y, w = imgW, h = imgH,
        }
    end
    return placed
end

local function buildHTML(frame)
    local images = loadImages()
    local placed = scatter(frame, images)

    local imgsHtml = ""
    if #placed > 0 then
        for _, p in ipairs(placed) do
            local uri = fileToDataURI(p.entry)
            if uri then
                imgsHtml = imgsHtml .. string.format(
                    '<img src="%s" style="left:%.3f%%;top:%.3f%%;width:%.3f%%;height:%.3f%%;" />',
                    uri, p.x, p.y, p.w, p.h)
            end
        end
    else
        imgsHtml = '<div class="emoji">' .. EMOJI .. '</div>'
    end

    local css = [[
html,body{margin:0;padding:0;background:#000;width:100vw;height:100vh;overflow:hidden;
  font-family:"Apple SD Gothic Neo",-apple-system,sans-serif;}
img{position:absolute;object-fit:contain;}
.emoji{position:absolute;top:18%;left:0;width:100%;text-align:center;font-size:220px;}
.msg{position:absolute;top:70%;left:3%;width:94%;height:20%;text-align:center;
  color:#fff;font-size:80px;font-weight:700;background:rgba(0,0,0,0.78);
  display:flex;align-items:center;justify-content:center;}
]]

    return "<!DOCTYPE html><html><head><meta charset='utf-8'><style>" ..
           css .. "</style></head><body>" .. imgsHtml ..
           "<div class='msg'>" .. MESSAGE .. "</div></body></html>"
end

local function buildOverlay()
    local screens = hs.screen.allScreens()
    if #screens < 2 then
        hs.alert.show("Privacy Shield: no second monitor detected")
        return nil
    end

    math.randomseed(os.time())

    local frame = screens[2]:fullFrame()
    local html  = buildHTML(frame)

    local wv = hs.webview.new(frame)
    wv:windowStyle({ "borderless" })
    wv:level(hs.drawing.windowLevels.overlay)
    wv:shadow(false)
    wv:allowTextEntry(false)
    wv:html(html)
    wv:bringToFront(true)
    wv:show()
    return wv
end

local function hideOtherApps()
    local hidden = {}
    for _, app in ipairs(hs.application.runningApplications()) do
        if app:kind() == 1
           and app:name() ~= KEEP_APP
           and app:name() ~= "Hammerspoon"
           and app:name() ~= "Finder"
           and not app:isHidden() then
            if app:hide() then
                table.insert(hidden, app)
            end
        end
    end
    return hidden
end

local function restoreApps(apps)
    for _, app in ipairs(apps) do
        pcall(function() app:unhide() end)
    end
end

local function activate()
    state.previousApp = hs.application.frontmostApplication()
    state.hiddenApps  = hideOtherApps()
    state.overlay     = buildOverlay()

    local iterm = hs.application.find(KEEP_APP)
    if iterm then iterm:activate(true) end

    state.active = true
end

local function deactivate()
    if state.overlay then
        state.overlay:delete()
        state.overlay = nil
    end
    restoreApps(state.hiddenApps)
    state.hiddenApps = {}
    state.active = false
end

hs.hotkey.bind(MODS, KEY, function()
    if state.active then deactivate() else activate() end
end)

hs.alert.show("Privacy Shield loaded — ⌃⌥⌘H")
