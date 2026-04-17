-- Privacy Shield — 망그러진곰 edition.
-- 모니터 훔쳐보는 동료 퇴치용 (귀엽게)
-- ⌃⌥⌘H: 두 번째 모니터에만 오버레이
-- ⌃⌥⌘F: 전 모니터에 오버레이 (전역 차단)

local MODS       = { "ctrl", "alt", "cmd" }
local KEY_SECOND = "H"
local KEY_FULL   = "F"
local KEEP_APP   = "iTerm2"

local MESSAGE = "훔쳐보지 마... 망곰이가 보고 있다구..."
local EMOJI   = "(o_o )"

local IMAGES_DIR = "images/bear"

local MIME = {
    png  = "image/png",
    jpg  = "image/jpeg",
    jpeg = "image/jpeg",
    gif  = "image/gif",
    heic = "image/heic",
    bmp  = "image/bmp",
    webp = "image/webp",
}

local KS_W, KS_H = 170, 44

-- Cleanup previous load (prevents duplicates on Reload Config).
if _G._privacyShield then
    local old = _G._privacyShield
    if old.hotkeySecond then old.hotkeySecond:delete() end
    if old.hotkeyFull   then old.hotkeyFull:delete() end
    if old.ks1 then old.ks1:delete() end
    if old.ks2 then old.ks2:delete() end
    if old.menubar then old.menubar:delete() end
    if old.overlays then
        for _, o in ipairs(old.overlays) do pcall(function() o:delete() end) end
    end
end
_G._privacyShield = {}

local state = {
    active      = false,
    mode        = nil,
    overlays    = {},
    hiddenApps  = {},
    ks1         = nil,
    ks2         = nil,
    ksVisible   = true,
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
@keyframes floatDots {
  0%, 100% { opacity: 0.25; }
  50% { opacity: 0.55; }
}
html, body {
  margin: 0; padding: 0;
  width: 100vw; height: 100vh;
  overflow: hidden;
  font-family: "Apple SD Gothic Neo", -apple-system, sans-serif;
  background: #FFEBEE;
}
body::before {
  content: "";
  position: fixed; inset: 0;
  background:
    radial-gradient(circle, rgba(244,143,177,0.25) 2px, transparent 2px),
    radial-gradient(circle, rgba(255,183,77,0.2) 2px, transparent 2px);
  background-size: 60px 60px, 80px 80px;
  background-position: 0 0, 30px 40px;
  animation: floatDots 4s ease-in-out infinite;
  pointer-events: none;
  z-index: 1;
}
img {
  position: absolute;
  object-fit: contain;
  z-index: 5;
  filter: drop-shadow(0 4px 12px rgba(0,0,0,0.1));
}
.emoji {
  position: absolute;
  top: 15%; left: 0; width: 100%;
  text-align: center;
  font-size: 180px;
  color: #5D4037;
  z-index: 5;
}
.msg-box {
  position: absolute;
  top: 35%; left: 50%;
  transform: translateX(-50%);
  max-width: 90%;
  padding: 36px 56px;
  background: rgba(255, 255, 255, 0.92);
  border-radius: 32px;
  border: 3px solid #F48FB1;
  box-shadow: 0 8px 40px rgba(244,143,177,0.3);
  text-align: center;
  z-index: 10;
}
.msg-box .text {
  color: #4E342E;
  font-size: 56px;
  font-weight: 800;
  line-height: 1.4;
}
.msg-box .sub {
  margin-top: 16px;
  color: #F48FB1;
  font-size: 28px;
  font-weight: 600;
  letter-spacing: 0.08em;
}
.corner-label {
  position: absolute;
  bottom: 3%; right: 3%;
  color: #F48FB1;
  font-size: 32px;
  font-weight: 900;
  letter-spacing: 0.15em;
  opacity: 0.7;
  z-index: 10;
}
]]

    return table.concat({
        "<!DOCTYPE html><html><head><meta charset='utf-8'><style>",
        css,
        "</style></head><body>",
        imgsHtml,
        "<div class='msg-box'>",
          "<div class='text'>", MESSAGE, "</div>",
          "<div class='sub'>- mangom -</div>",
        "</div>",
        "<div class='corner-label'>mangom shield</div>",
        "</body></html>",
    })
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
            ks["dot"].fillColor      = { red = 0.96, green = 0.26, blue = 0.21, alpha = 1 }
            ks["label"].text         = "ON"
            ks["label"].textColor    = { red = 0.96, green = 0.26, blue = 0.21, alpha = 1 }
            ks["border"].strokeColor = { red = 0.96, green = 0.56, blue = 0.69, alpha = 1 }
        else
            ks["dot"].fillColor      = { red = 0.56, green = 0.79, blue = 0.59, alpha = 1 }
            ks["label"].text         = "OFF"
            ks["label"].textColor    = { red = 0.55, green = 0.45, blue = 0.4, alpha = 1 }
            ks["border"].strokeColor = { red = 0.85, green = 0.75, blue = 0.72, alpha = 1 }
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
        fillColor = { red = 1, green = 0.97, blue = 0.95, alpha = 0.95 },
        roundedRectRadii = { xRadius = 12, yRadius = 12 },
    })
    c:appendElements({
        id = "border", type = "rectangle", action = "stroke",
        strokeColor = { red = 0.85, green = 0.75, blue = 0.72, alpha = 1 },
        strokeWidth = 2,
        roundedRectRadii = { xRadius = 12, yRadius = 12 },
    })
    c:appendElements({
        type = "text", text = title,
        textColor = { red = 0.36, green = 0.2, blue = 0.17, alpha = 1 },
        textSize = 15, textFont = "AppleSDGothicNeo-Bold",
        frame = { x = "6%", y = "12%", w = "38%", h = "76%" },
    })
    c:appendElements({
        id = "dot", type = "circle", action = "fill",
        fillColor = { red = 0.56, green = 0.79, blue = 0.59, alpha = 1 },
        center = { x = "52%", y = "50%" }, radius = "9%",
    })
    c:appendElements({
        id = "label", type = "text", text = "OFF",
        textColor = { red = 0.55, green = 0.45, blue = 0.4, alpha = 1 },
        textSize = 13, textFont = "AppleSDGothicNeo-Bold",
        frame = { x = "58%", y = "12%", w = "38%", h = "76%" },
    })

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

-- Menubar ---------------------------------------------------------------------

local function toggleKsVisibility()
    state.ksVisible = not state.ksVisible
    if state.ksVisible then
        if state.ks1 then state.ks1:show() end
        if state.ks2 then state.ks2:show() end
    else
        if state.ks1 then state.ks1:hide() end
        if state.ks2 then state.ks2:hide() end
    end
end

local function createMenubar()
    local mb = hs.menubar.new()
    mb:setTitle("B")
    mb:setMenu(function()
        local modeLabel = "OFF"
        if state.mode == "second" then modeLabel = "2nd Monitor"
        elseif state.mode == "full" then modeLabel = "Full" end

        return {
            { title = "Privacy Shield - mangom", disabled = true },
            { title = "-" },
            { title = state.ksVisible and "Hide Buttons" or "Show Buttons",
              fn = toggleKsVisibility },
            { title = "-" },
            { title = "⌃⌥⌘H  2nd Monitor",
              fn = toggleSecond,
              checked = (state.mode == "second") },
            { title = "⌃⌥⌘F  Full Screen",
              fn = toggleFull,
              checked = (state.mode == "full") },
            { title = "-" },
            { title = "Status: " .. modeLabel, disabled = true },
        }
    end)
    return mb
end

-- Bootstrap -------------------------------------------------------------------

_G._privacyShield.hotkeySecond = hs.hotkey.bind(MODS, KEY_SECOND, toggleSecond)
_G._privacyShield.hotkeyFull   = hs.hotkey.bind(MODS, KEY_FULL,   toggleFull)

local scr = hs.screen.primaryScreen():frame()
state.ks1 = createKillSwitch("mangom", scr.x + scr.w - KS_W - 16,     scr.y + 8, toggleSecond)
state.ks2 = createKillSwitch("full",   scr.x + scr.w - KS_W * 2 - 24, scr.y + 8, toggleFull)
_G._privacyShield.ks1      = state.ks1
_G._privacyShield.ks2      = state.ks2
_G._privacyShield.overlays = state.overlays
_G._privacyShield.menubar  = createMenubar()

hs.alert.show("Privacy Shield - mangom - ⌃⌥⌘H / ⌃⌥⌘F")
