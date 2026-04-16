-- Privacy Shield: hide everything except iTerm2, taunt the creeper.
-- ⌃⌥⌘H: overlay on second monitor only (keep iTerm2 on primary)
-- ⌃⌥⌘F: overlay on ALL monitors (total blackout)

local MODS       = { "ctrl", "alt", "cmd" }
local KEY_SECOND = "H"
local KEY_FULL   = "F"
local KEEP_APP   = "iTerm2"

local MESSAGE = "남의 모니터 뭐가 그래 재밌어보이노 그만봐라"
local EMOJI   = "👀"

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

local KS_W, KS_H = 160, 44

-- Cleanup previous load (prevents duplicates on Reload Config).
if _G._privacyShield then
    local old = _G._privacyShield
    if old.hotkeySecond then old.hotkeySecond:delete() end
    if old.hotkeyFull   then old.hotkeyFull:delete() end
    if old.ks1 then old.ks1:delete() end
    if old.ks2 then old.ks2:delete() end
    if old.overlays then
        for _, o in ipairs(old.overlays) do pcall(function() o:delete() end) end
    end
end
_G._privacyShield = {}

local state = {
    active      = false,
    mode        = nil,   -- nil | "second" | "full"
    overlays    = {},
    hiddenApps  = {},
    ks1         = nil,
    ks2         = nil,
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
        local sizeRatio = 0.72 + math.random() * 0.20
        local imgW = cellW * sizeRatio
        local imgH = cellH * sizeRatio
        local x = cell.col * cellW + (cellW - imgW) * math.random()
        local y = cell.row * cellH + (cellH - imgH) * math.random()
        placed[i] = { entry = entry, x = x, y = y, w = imgW, h = imgH }
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
.msg{position:absolute;top:35%;left:3%;width:94%;height:20%;text-align:center;
  color:#fff;font-size:80px;font-weight:700;background:rgba(0,0,0,0.78);
  display:flex;align-items:center;justify-content:center;}
]]

    return "<!DOCTYPE html><html><head><meta charset='utf-8'><style>" ..
           css .. "</style></head><body>" .. imgsHtml ..
           "<div class='msg'>" .. MESSAGE .. "</div></body></html>"
end

local function buildOverlay(screen)
    local frame = screen:fullFrame()
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

local function deactivate()
    for _, wv in ipairs(state.overlays) do
        pcall(function() wv:delete() end)
    end
    state.overlays = {}
    restoreApps(state.hiddenApps)
    state.hiddenApps = {}
    state.active = false
    state.mode   = nil
end

local function activateSecond()
    if state.active then deactivate() end
    local screens = hs.screen.allScreens()
    if #screens < 2 then
        hs.alert.show("Privacy Shield: no second monitor detected")
        return
    end
    math.randomseed(os.time())
    state.hiddenApps = hideOtherApps()
    table.insert(state.overlays, buildOverlay(screens[2]))
    local iterm = hs.application.find(KEEP_APP)
    if iterm then iterm:activate(true) end
    state.active = true
    state.mode   = "second"
end

local function activateFull()
    if state.active then deactivate() end
    math.randomseed(os.time())
    -- Don't hide apps — opaque overlay covers everything anyway.
    for _, screen in ipairs(hs.screen.allScreens()) do
        table.insert(state.overlays, buildOverlay(screen))
    end
    state.active = true
    state.mode   = "full"
end

-- Kill switches ---------------------------------------------------------------

local function updateKillSwitches()
    local function applyStyle(ks, on)
        if not ks then return end
        if on then
            ks["dot"].fillColor      = { red = 1, green = 0.15, blue = 0.1, alpha = 1 }
            ks["label"].text         = "ON"
            ks["label"].textColor    = { red = 1, green = 0.2, blue = 0.1, alpha = 1 }
            ks["border"].strokeColor = { red = 1, green = 0.15, blue = 0.1, alpha = 1 }
        else
            ks["dot"].fillColor      = { red = 0, green = 0.75, blue = 0.3, alpha = 1 }
            ks["label"].text         = "OFF"
            ks["label"].textColor    = { red = 0.85, green = 0.85, blue = 0.85, alpha = 1 }
            ks["border"].strokeColor = { red = 0.4, green = 0.4, blue = 0.4, alpha = 1 }
        end
    end
    applyStyle(state.ks1, state.mode == "second")
    applyStyle(state.ks2, state.mode == "full")
end

local function toggleSecond()
    if state.active and state.mode == "second" then deactivate()
    else activateSecond() end
    updateKillSwitches()
end

local function toggleFull()
    if state.active and state.mode == "full" then deactivate()
    else activateFull() end
    updateKillSwitches()
end

local function createKillSwitch(title, xPos, yPos, toggleFn)
    local c = hs.canvas.new({ x = xPos, y = yPos, w = KS_W, h = KS_H })

    c:appendElements({
        type = "rectangle", action = "fill",
        fillColor = { red = 0.1, green = 0.1, blue = 0.1, alpha = 0.92 },
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
    })
    c:appendElements({
        id = "border", type = "rectangle", action = "stroke",
        strokeColor = { red = 0.4, green = 0.4, blue = 0.4, alpha = 1 },
        strokeWidth = 2,
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
    })
    c:appendElements({
        type = "text", text = title,
        textColor = { red = 0.85, green = 0.85, blue = 0.85, alpha = 1 },
        textSize = 16, textFont = "Helvetica-Bold",
        frame = { x = "6%", y = "12%", w = "38%", h = "76%" },
    })
    c:appendElements({
        id = "dot", type = "circle", action = "fill",
        fillColor = { red = 0, green = 0.75, blue = 0.3, alpha = 1 },
        center = { x = "52%", y = "50%" }, radius = "9%",
    })
    c:appendElements({
        id = "label", type = "text", text = "OFF",
        textColor = { red = 0.85, green = 0.85, blue = 0.85, alpha = 1 },
        textSize = 14, textFont = "Helvetica-Bold",
        frame = { x = "58%", y = "12%", w = "38%", h = "76%" },
    })

    -- screenSaver level so buttons stay above overlays in full mode.
    c:level(hs.drawing.windowLevels.screenSaver)
    c:canvasMouseEvents(true, true, false, true)

    local drag = nil
    c:mouseCallback(function(canvas, msg, id, mx, my)
        if msg == "mouseDown" then
            local pos = hs.mouse.absolutePosition()
            local f   = canvas:frame()
            drag = { ox = pos.x - f.x, oy = pos.y - f.y, moved = false }
        elseif msg == "mouseUp" then
            if drag and not drag.moved then toggleFn() end
            drag = nil
        elseif msg == "mouseMove" and drag then
            local pos = hs.mouse.absolutePosition()
            canvas:frame({ x = pos.x - drag.ox, y = pos.y - drag.oy, w = KS_W, h = KS_H })
            drag.moved = true
        end
    end)

    c:show()
    return c
end

-- Bootstrap -------------------------------------------------------------------

_G._privacyShield.hotkeySecond = hs.hotkey.bind(MODS, KEY_SECOND, toggleSecond)
_G._privacyShield.hotkeyFull   = hs.hotkey.bind(MODS, KEY_FULL,   toggleFull)

local scr = hs.screen.primaryScreen():frame()
state.ks1 = createKillSwitch("2nd",  scr.x + scr.w - KS_W - 16,     scr.y + 8, toggleSecond)
state.ks2 = createKillSwitch("Full", scr.x + scr.w - KS_W * 2 - 24, scr.y + 8, toggleFull)
_G._privacyShield.ks1      = state.ks1
_G._privacyShield.ks2      = state.ks2
_G._privacyShield.overlays = state.overlays

hs.alert.show("Privacy Shield loaded — ⌃⌥⌘H / ⌃⌥⌘F")
