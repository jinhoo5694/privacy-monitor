-- Privacy Shield — EVA edition.
-- 特務機関 NERV 모드: 사도 요격 경보를 모니터에 띄운다.
-- ⌃⌥⌘H: 두 번째 모니터에만 오버레이
-- ⌃⌥⌘F: 전 모니터에 오버레이 (전역 차단)

local MODS       = { "ctrl", "alt", "cmd" }
local KEY_SECOND = "H"
local KEY_FULL   = "F"
local KEEP_APP   = "iTerm2"

local IMAGES_DIR = "images/eva"
local FONTS_DIR  = "fonts"

local MIME = {
    png  = "image/png",
    jpg  = "image/jpeg",
    jpeg = "image/jpeg",
    gif  = "image/gif",
    heic = "image/heic",
    bmp  = "image/bmp",
    webp = "image/webp",
}

local FONT_MIME = {
    ttf = "font/ttf",
    otf = "font/otf",
    woff = "font/woff",
    woff2 = "font/woff2",
}

local KS_W, KS_H = 190, 50

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
    mode        = nil,   -- nil | "second" | "full"
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

local function listFiles(dir, extensions)
    local full = scriptDir() .. dir
    local out = {}
    if not hs.fs.attributes(full) then return out end
    for file in hs.fs.dir(full) do
        local ext = file:lower():match("%.(%w+)$")
        if ext and extensions[ext] then
            table.insert(out, { path = full .. "/" .. file, ext = ext })
        end
    end
    table.sort(out, function(a, b) return a.path < b.path end)
    return out
end

local function fileToDataURI(entry, mimeTable)
    local f = io.open(entry.path, "rb")
    if not f then return nil end
    local data = f:read("*all")
    f:close()
    return "data:" .. mimeTable[entry.ext] .. ";base64," .. hs.base64.encode(data)
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

local function buildFontFace()
    local fonts = listFiles(FONTS_DIR, FONT_MIME)
    if #fonts == 0 then return "" end
    local uri = fileToDataURI(fonts[1], FONT_MIME)
    if not uri then return "" end
    return string.format([[
@font-face {
  font-family: "NERV";
  src: url("%s");
  font-weight: 900;
  font-display: block;
}
]], uri)
end

local function buildHTML(frame)
    local images = listFiles(IMAGES_DIR, MIME)
    local placed = scatter(frame, images)

    local imgsHtml = ""
    for _, p in ipairs(placed) do
        local uri = fileToDataURI(p.entry, MIME)
        if uri then
            imgsHtml = imgsHtml .. string.format(
                '<img src="%s" style="left:%.3f%%;top:%.3f%%;width:%.3f%%;height:%.3f%%;" />',
                uri, p.x, p.y, p.w, p.h)
        end
    end

    local fontFace = buildFontFace()

    local css = [[
html, body {
  margin: 0; padding: 0;
  width: 100vw; height: 100vh;
  background: #050000;
  overflow: hidden;
  color: #ff6600;
  font-family: "NERV", "Impact", "Helvetica Neue Condensed Bold",
               "Hiragino Sans", "Hiragino Kaku Gothic StdN", sans-serif;
  -webkit-font-smoothing: antialiased;
}

.images img {
  position: absolute;
  object-fit: contain;
  filter: saturate(0.85) contrast(1.05);
}

.warning-border {
  position: fixed; inset: 0;
  box-shadow: inset 0 0 0 28px #ff0000,
              inset 0 0 140px 28px rgba(255, 0, 0, 0.55);
  pointer-events: none;
  animation: alarmBlink 0.45s steps(1) infinite;
  z-index: 50;
}
@keyframes alarmBlink {
  0%, 49.99% { opacity: 1; }
  50%, 100%  { opacity: 0.18; }
}

.scan-lines {
  position: fixed; inset: 0;
  background: linear-gradient(rgba(255,255,255,0.02) 50%,
                              rgba(0,0,0,0.22) 50%);
  background-size: 100% 4px;
  pointer-events: none;
  mix-blend-mode: overlay;
  z-index: 60;
}

.nerv-logo {
  position: absolute;
  top: 3%; right: 3%;
  color: #ff7a00;
  font-size: 90px;
  font-weight: 900;
  letter-spacing: 0.35em;
  text-shadow: 0 0 18px rgba(255, 122, 0, 0.9);
  z-index: 70;
}
.nerv-logo small {
  display: block;
  font-size: 22px;
  letter-spacing: 0.25em;
  color: #ffaa55;
  margin-top: 4px;
}

.text-warning {
  position: absolute;
  top: 4%; left: 4%;
  color: #ff8800;
  font-size: 120px;
  font-weight: 900;
  letter-spacing: 0.08em;
  text-shadow: 0 0 28px rgba(255, 136, 0, 0.8);
  animation: warnBlink 0.35s steps(1) infinite;
  z-index: 70;
}
@keyframes warnBlink {
  0%, 49.99% { opacity: 1; }
  50%, 100%  { opacity: 0.35; }
}

.text-main {
  position: absolute;
  bottom: 22%;
  left: 0; width: 100%;
  text-align: center;
  color: #ffd400;
  font-size: 180px;
  font-weight: 900;
  letter-spacing: 0.04em;
  text-shadow: 0 0 48px rgba(255, 40, 0, 0.9),
               0 0 18px rgba(0, 0, 0, 0.85);
  z-index: 70;
}

.text-sub {
  position: absolute;
  bottom: 10%;
  left: 0; width: 100%;
  text-align: center;
  color: #ff3b00;
  font-size: 96px;
  font-weight: 900;
  letter-spacing: 0.06em;
  text-shadow: 0 0 32px rgba(255, 0, 0, 0.8),
               0 0 10px rgba(0, 0, 0, 0.9);
  z-index: 70;
}

.side-texts {
  position: absolute;
  top: 35%; left: 2%;
  color: #ff0000;
  font-size: 46px;
  font-weight: 900;
  line-height: 1.35;
  text-shadow: 0 0 12px rgba(255, 0, 0, 0.8);
  animation: warnBlink 0.55s steps(1) infinite;
  z-index: 70;
}

.status-bar {
  position: absolute;
  top: 40%; right: 2%;
  text-align: right;
  color: #ffa500;
  font-size: 28px;
  letter-spacing: 0.12em;
  line-height: 1.6;
  font-family: "Menlo", "Courier New", monospace;
  text-shadow: 0 0 10px rgba(255, 165, 0, 0.6);
  z-index: 70;
}
.status-bar .val { color: #ff0000; }

.pattern-blue {
  position: absolute;
  bottom: 2.5%; right: 3%;
  color: #00c8ff;
  font-size: 44px;
  font-weight: 900;
  letter-spacing: 0.1em;
  font-family: "Menlo", "Courier New", monospace;
  text-shadow: 0 0 14px rgba(0, 200, 255, 0.7);
  z-index: 70;
}

.crosshair {
  position: absolute;
  top: 50%; left: 50%;
  width: 320px; height: 320px;
  margin: -160px 0 0 -160px;
  border: 2px solid rgba(255, 120, 0, 0.45);
  border-radius: 50%;
  pointer-events: none;
  z-index: 55;
}
.crosshair::before,
.crosshair::after {
  content: "";
  position: absolute;
  background: rgba(255, 120, 0, 0.45);
}
.crosshair::before { top: 0; bottom: 0; left: 50%; width: 1px; }
.crosshair::after  { left: 0; right: 0; top: 50%; height: 1px; }
]]

    return table.concat({
        "<!DOCTYPE html><html><head><meta charset='utf-8'><style>",
        fontFace, css,
        "</style></head><body>",
        "<div class='images'>", imgsHtml, "</div>",
        "<div class='crosshair'></div>",
        "<div class='warning-border'></div>",
        "<div class='scan-lines'></div>",
        "<div class='nerv-logo'>NERV<small>特務機関</small></div>",
        "<div class='text-warning'>WARNING</div>",
        "<div class='side-texts'>警告<br>警告<br>緊急事態発生<br>迎撃開始</div>",
        "<div class='status-bar'>",
          "NERV CENTRAL DOGMA<br>",
          "AT FIELD : <span class='val'>ACTIVE</span><br>",
          "STATUS : <span class='val'>ENGAGING</span><br>",
          "MAGI : <span class='val'>CASPER · MELCHIOR · BALTHASAR</span>",
        "</div>",
        "<div class='text-main'>使徒迎撃中</div>",
        "<div class='text-sub'>A.T.フィールド展開</div>",
        "<div class='pattern-blue'>PATTERN : BLUE</div>",
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
            ks["dot"].fillColor      = { red = 1, green = 0, blue = 0, alpha = 1 }
            ks["status"].text        = "迎撃中"
            ks["status"].textColor   = { red = 1, green = 0.2, blue = 0.1, alpha = 1 }
            ks["border"].strokeColor = { red = 1, green = 0, blue = 0, alpha = 1 }
        else
            ks["dot"].fillColor      = { red = 0, green = 0.8, blue = 0.27, alpha = 1 }
            ks["status"].text        = "待機中"
            ks["status"].textColor   = { red = 0.93, green = 0.93, blue = 0.93, alpha = 1 }
            ks["border"].strokeColor = { red = 1, green = 0.4, blue = 0, alpha = 1 }
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
        fillColor = { red = 0.04, green = 0, blue = 0, alpha = 0.92 },
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
    })
    c:appendElements({
        id = "border", type = "rectangle", action = "stroke",
        strokeColor = { red = 1, green = 0.4, blue = 0, alpha = 1 },
        strokeWidth = 2,
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
    })
    c:appendElements({
        type = "text", text = title,
        textColor = { red = 1, green = 0.48, blue = 0, alpha = 1 },
        textSize = 18, textFont = "Impact",
        frame = { x = "5%", y = "10%", w = "32%", h = "80%" },
    })
    c:appendElements({
        id = "dot", type = "circle", action = "fill",
        fillColor = { red = 0, green = 0.8, blue = 0.27, alpha = 1 },
        center = { x = "44%", y = "50%" }, radius = "8%",
    })
    c:appendElements({
        id = "status", type = "text", text = "待機中",
        textColor = { red = 0.93, green = 0.93, blue = 0.93, alpha = 1 },
        textSize = 16, textFont = "HiraginoSans-W7",
        frame = { x = "50%", y = "10%", w = "46%", h = "80%" },
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
    mb:setTitle("N")
    mb:setMenu(function()
        local modeLabel = "OFF"
        if state.mode == "second" then modeLabel = "2nd Monitor"
        elseif state.mode == "full" then modeLabel = "Full" end

        return {
            { title = "Privacy Shield — EVA", disabled = true },
            { title = "-" },
            { title = state.ksVisible and "버튼 숨기기" or "버튼 표시",
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
state.ks1 = createKillSwitch("NERV", scr.x + scr.w - KS_W - 16,     scr.y + 8, toggleSecond)
state.ks2 = createKillSwitch("全域", scr.x + scr.w - KS_W * 2 - 24, scr.y + 8, toggleFull)
_G._privacyShield.ks1      = state.ks1
_G._privacyShield.ks2      = state.ks2
_G._privacyShield.overlays = state.overlays
_G._privacyShield.menubar  = createMenubar()

hs.alert.show("Privacy Shield — EVA — ⌃⌥⌘H / ⌃⌥⌘F")
