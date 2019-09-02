-- Watchers and other useful objects
local screenWatcher = nil

-- Define monitor names for layout purposes
local display_laptop = "Color LCD"

-- Defines for screen watcher
local lastNumberOfScreens = #hs.screen.allScreens()
-- 第二个显示器名称，如果多屏幕时才赋值。 
local display_monitor
if lastNumberOfScreens > 1 then 
  display_monitor = hs.screen.allScreens()[2]:name() 
end

-- Defines for window grid
hs.grid.GRIDWIDTH = 2
hs.grid.GRIDHEIGHT = 2
hs.grid.MARGINX = 0
hs.grid.MARGINY = 0
local moveMaxWidth = hs.grid.GRIDWIDTH / 2 + 1
local moveMinWidth = hs.grid.GRIDWIDTH / 2 - 1
-- Defines for window maximize toggler
local frameCache = {}

-- key define 快捷键的修饰键
local hyper = {'ctrl', 'cmd', 'shift', 'alt'}
local hyperAlt = {'ctrl', 'cmd'}

-- states
hs.window.animationDuration = 0

-- App shortcuts  程序快捷键，一键启动加切换
-- hyperAlt（ctrl+cmd+alt） + 前面的字母就可以了 
local key2App = {
    i = 'iTerm',
    y = 'YoudaoNote',
    m = 'Mail',
    b = 'Google Chrome',
    f = 'Finder',
    n = 'NeteaseMusic',
    s = 'System Preferences',
    q = 'QQ'
}
for key, app in pairs(key2App) do
  --hs.hotkey.bind(hyper, key, function() hs.application.launchOrFocus(app) end)
  hs.hotkey.bind(hyperAlt, key, function() toggle_application(app) end)
end

hs.hotkey.bind({"cmd", "ctrl"}, "1", function()
  hs.application.launchOrFocus("iTerm")
end)
hs.hotkey.bind({"cmd", "ctrl"}, "2", function()
  hs.application.launchOrFocus("Google Chrome")
end)
hs.hotkey.bind({"cmd", "ctrl"}, "3", function()
  hs.application.launchOrFocus("QQ")
end)

function toggle_application(_app)
    -- finds a running applications
    local app = hs.application.find(_app)

    if not app then
        -- application not running, launch app
        hs.application.launchOrFocus(_app)
        return
    end

    -- application running, toggle hide/unhide
    local mainwin = app:mainWindow()
    if mainwin then
        if true == app:isFrontmost() then
            mainwin:application():hide()
        else
            mainwin:application():activate(true)
            mainwin:application():unhide()
            mainwin:focus()
        end
    else
        -- no windows, maybe hide
        if true == app:hide() then
            -- focus app
            hs.application.launchOrFocus(_app)
        else
            -- nothing to do
        end
    end
end

-- Define window layouts  单屏幕多屏幕窗口布局
--   Format reminder:
--     {"App name", "Window name", "Display Name", "unitrect", "framerect", "fullframerect"},
--
-- 笔记本屏幕，主屏幕 
-- 用到了hs.layout 插件，很方便，right50=屏幕右边50%，其它参数请自行查阅hammerspoon文档
local internal_display= {
      {"Google Chrome",    nil,      diaplay_laptop, hs.layout.maximized, nil, nil},
      {"Sublime Text",    nil,      diaplay_laptop, hs.layout.maximized, nil, nil},
      {"Mail",      nil,      display_laptop, hs.layout.right50,   nil, nil},
      {"iTerm",     nil,      display_laptop, hs.layout.right50,   nil, nil},
      {"Finder",    nil,      display_laptop, hs.layout.right70,   nil, nil},
  }

-- 两个屏幕时
-- local secondScreen = hs.screen.allScreens()[2]:name()
local dual_display= {
    {"Safari",  nil,          display_laptop,  hs.layout.maximized, nil, nil},
    {"Mail",    nil,          display_monitor, hs.layout.right50,   nil, nil},
    {"iTerm",   nil,          display_monitor, hs.layout.left50,    nil, nil},
    {"Finder",  nil,          display_monitor, hs.layout.right70,   nil, nil},
  }

-- Helper functions

-- Replace Caffeine.app with 18 lines of Lua :D 系统咖啡因，禁止系统休眠，几行代码搞定
local caffeine = hs.menubar.new()

function setCaffeineDisplay(state)
    local result
    if state then
        result = caffeine:setIcon("caffeine-on.pdf")
    else
        result = caffeine:setIcon("caffeine-off.pdf")
    end
end

function caffeineClicked()
    setCaffeineDisplay(hs.caffeinate.toggle("displayIdle"))
  end

if caffeine then
    caffeine:setClickCallback(caffeineClicked)
    setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
  end

-- Toggle a window between its normal size, and being maximized 窗口最大化切换
function toggle_window_maximized()
    local win = hs.window.focusedWindow()
    if frameCache[win:id()] then
        win:setFrame(frameCache[win:id()])
        frameCache[win:id()] = nil
    else
        frameCache[win:id()] = win:frame()
        win:maximize()
      end
end

-- Callback function for application events  
function applicationWatcher(appName, eventType, appObject)
    if (eventType == hs.application.watcher.activated) then
        if (appName == "Finder") then
            -- Bring all Finder windows forward when one gets activated
            appObject:selectMenuItem({"Window", "Bring All to Front"})
        elseif (appName == "iTunes") then
            -- Ensure the MiniPlayer window is visible and correctly placed, since it likes to hide an awful lot
            state = appObject:findMenuItem({"Window", "MiniPlayer"})
            if state and not state["ticked"] then
                appObject:selectMenuItem({"Window", "MiniPlayer"})
            end
            _animationDuration = hs.window.animationDuration
            hs.window.animationDuration = 0
            hs.layout.apply({ iTunesMiniPlayerLayout })
            hs.window.animationDuration = _animationDuration
        end
    end
end

function center(window)
  frame = window:screen():frame()
  frame.x = (frame.w / 2) - (frame.w / 4)
  frame.y = (frame.h / 2) - (frame.h / 4)
  frame.w = frame.w / 2
  frame.h = frame.h / 2
  window:setFrame(frame)
end

-- Callback function for changes in screen layout
function screensChangedCallback()
    newNumberOfScreens = #hs.screen.allScreens()

    -- FIXME: This is awful if we swap primary screen to the external display. all the windows swap around, pointlessly.
    if lastNumberOfScreens ~= newNumberOfScreens then
        if newNumberOfScreens == 1 then
            hs.layout.apply(internal_display)
        elseif newNumberOfScreens == 2 then
            hs.layout.apply(dual_display)
        end
    end
    lastNumberOfScreens = newNumberOfScreens
  end

-- I always end up losing my mouse pointer, particularly if it's on a monitor full of terminals.
-- This draws a bright red circle around the pointer for a few seconds
function mouseHighlight()
    if mouseCircle then
        mouseCircle:delete()
        if mouseCircleTimer then
            mouseCircleTimer:stop()
        end
    end
    mousepoint = hs.mouse.getAbsolutePosition()
    mouseCircle = hs.drawing.circle(hs.geometry.rect(mousepoint.x-40, mousepoint.y-40, 80, 80))
    mouseCircle:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    mouseCircle:setFill(false)
    mouseCircle:setStrokeWidth(5)
    mouseCircle:bringToFront(true)
    mouseCircle:show()

    mouseCircleTimer = hs.timer.doAfter(3, function() mouseCircle:delete() end)
end

-- Rather than switch to Safari, copy the current URL, switch back to the previous app and paste,
-- This is a function that fetches the current URL from Safari and types it
function typeCurrentSafariURL()
    script = [[
    tell application "Safari"
        set currentURL to URL of document 1
    end tell
    return currentURL
    ]]
    ok, result = hs.applescript(script)
    if (ok) then
        hs.eventtap.keyStrokes(result)
    end
end

-- Hints  非常赞的功能，类似图拉鼎同学的Monico
-- utils
function getAllValidWindows ()
    local allWindows = hs.window.allWindows()
    local windows = {}
    local index = 1
    for i = 1, #allWindows do
        local w = allWindows[i]
        if w:screen() then
            windows[index] = w
            index = index + 1
        end
    end
    return windows
end

hs.hotkey.bind(hyper, "tab", function()
    hs.hints.windowHints(getAllValidWindows())
    --hs.hints.windowHints()
end)

switcher_space = hs.window.switcher.new(hs.window.filter.new():setCurrentSpace(true):setDefaultFilter{}) -- include minimized/hidden windows, current Space only

-- bind to hotkeys; WARNING: at least one modifier key is required!
-- hs.hotkey.bind('alt','tab','Next window',function()switcher_space:next()end)
-- hs.hotkey.bind('alt-shift','tab','Prev window',function()switcher_space:previous()end)

-- undo
local undo = require 'undo'
hs.hotkey.bind(hyper, 'z', function() undo:undo() end)

-- 这里使用了宋辰文同学的方向控制函数，感谢
-- Move Window
function horizontalMove(direction)
    local w = hs.window.focusedWindow()
    if not w or not w:isStandard() then return end
    local s = w:screen()
    if not s then return end
    local g = hs.grid.get(w)
    g.y = 0
    g.h = hs.grid.GRIDHEIGHT
    direction = direction / math.abs(direction)

    if g.x + g.w == hs.grid.GRIDWIDTH and g.x == 0 then
        if direction < 0 then
            g.w = g.w - direction
            g.x = hs.grid.GRIDWIDTH - g.w
        else
            g.w = g.w + direction
        end
        undo:addToStack()
        hs.grid.set(w, g, s)
    end

    if g.x + g.w == hs.grid.GRIDWIDTH then
        g.w = g.w - direction
        local toMove = false
        if g.w > moveMaxWidth then
            g.w = moveMaxWidth
            g.x = 0
            toMove = true
        elseif g.w >= moveMinWidth then
            g.x = hs.grid.GRIDWIDTH - g.w
            toMove = true
        end
        if toMove then
            undo:addToStack()
            hs.grid.set(w, g, s)
            if direction > 0 and g.x + g.w >= hs.grid.GRIDWIDTH then
                w:ensureIsInScreenBounds()
            end
        end
        return
    end

    if g.x == 0 then
        g.w = g.w + direction
        local toMove = false
        if g.w > moveMaxWidth then
            g.w = moveMaxWidth
            g.x = hs.grid.GRIDWIDTH - moveMaxWidth
            toMove = true
        elseif g.w >= moveMinWidth then
            toMove = true
        end
        if toMove then
            undo:addToStack()
            hs.grid.set(w, g, s)
        end
        return
    end

    g.w = hs.grid.GRIDWIDTH / 2
    g.x = direction > 0 and hs.grid.GRIDWIDTH / 2 or 0
    undo:addToStack()
    hs.grid.set(w, g, s)
end

local hyperLeft = hs.hotkey.bind(hyperAlt, 'left', function() horizontalMove(-1) end)

local hyperRight = hs.hotkey.bind(hyperAlt, 'right', function() horizontalMove(1) end)

-- Move Screen
hs.hotkey.bind(hyper, '[', function() 
    local w = hs.window.focusedWindow()
    if not w then 
        return
      end

    local s = w:screen():toWest()
    if s then
        undo:addToStack()
        w:moveToScreen(s)
      end
    end)

hs.hotkey.bind(hyper, ']', function() 
    local w = hs.window.focusedWindow()
    if not w then 
        return
      end
    
    local s = w:screen():toEast()
    if s then
        undo:addToStack()
        w:moveToScreen(s)
      end
    end)

-- reload
hs.hotkey.bind(hyperAlt, '`', function() hs.reload() end )
hs.alert.show("Config loaded")

-- utils
function getAllValidWindows ()
    local allWindows = hs.window.allWindows()
    local windows = {}
    local index = 1
    for i = 1, #allWindows do
        local w = allWindows[i]
        if w:screen() then
            windows[index] = w
            index = index + 1
        end
    end
    return windows
  end

-- DISPLAY FOCUS SWITCHING --

--One hotkey should just suffice for dual-display setups as it will naturally
--cycle through both.
--A second hotkey to reverse the direction of the focus-shift would be handy
--for setups with 3 or more displays.

--Bring focus to next display/screen
hs.hotkey.bind(hyper, "`", function ()
  focusScreen(hs.window.focusedWindow():screen():next())
end)

--Bring focus to previous display/screen
hs.hotkey.bind({"alt", "shift"}, "`", function() 
  focusScreen(hs.window.focusedWindow():screen():previous())
end)

--Predicate that checks if a window belongs to a screen
function isInScreen(screen, win)
  return win:screen() == screen
end

-- Brings focus to the scren by setting focus on the front-most application in it.
-- Also move the mouse cursor to the center of the screen. This is because
-- Mission Control gestures & keyboard shortcuts are anchored, oddly, on where the
-- mouse is focused.
function focusScreen(screen)
  --Get windows within screen, ordered from front to back.
  --If no windows exist, bring focus to desktop. Otherwise, set focus on
  --front-most application window.
  local windows = hs.fnutils.filter(
      hs.window.orderedWindows(),
      hs.fnutils.partial(isInScreen, screen))
  local windowToFocus = #windows > 0 and windows[1] or hs.window.desktop()
  windowToFocus:focus()

  -- Move mouse to center of screen
  local pt = hs.geometry.rectMidPoint(screen:fullFrame())
  hs.mouse.setAbsolutePosition(pt)
end



-- shortcuts 
hs.hotkey.bind(hyper, 'h', function() hs.window.focusedWindow():moveToUnit(hs.layout.left50) end)
hs.hotkey.bind(hyper, 'l', function() hs.window.focusedWindow():moveToUnit(hs.layout.right50) end)
hs.hotkey.bind(hyper, 'k', function() hs.window.focusedWindow():moveToUnit({x=0,y=0,w=1,h=0.5}) end)
hs.hotkey.bind(hyper, 'j', function() hs.window.focusedWindow():moveToUnit({x=0,y=0.5,w=1,h=0.5}) end)
hs.hotkey.bind(hyper, 'c', function() hs.window.focusedWindow():moveToUnit({x=0.15, y=0.15, w=0.7, h=0.7}) end)
hs.hotkey.bind(hyper, 'y', function() hs.window.focusedWindow():moveToUnit(hs.layout.left30) end)
hs.hotkey.bind(hyper, 'p', function() hs.window.focusedWindow():moveToUnit(hs.layout.right70) end)
hs.hotkey.bind(hyper, 'o', toggle_window_maximized)
hs.hotkey.bind(hyper, 'r', function() hs.window.focusedWindow():toggleFullScreen() end)

-- Hotkeys to trigger defined layouts
hs.hotkey.bind(hyper, '1', function() hs.layout.apply(internal_display) end)
hs.hotkey.bind(hyper, '2', function() hs.layout.apply(dual_display) end)


-- Hotkeys to interact with the window grid
hs.hotkey.bind(hyper, 'g', hs.grid.show)
hs.hotkey.bind(hyper, 'Left', hs.grid.pushWindowLeft)
hs.hotkey.bind(hyper, 'Right', hs.grid.pushWindowRight)
hs.hotkey.bind(hyper, 'Up', hs.grid.pushWindowUp)
hs.hotkey.bind(hyper, 'Down', hs.grid.pushWindowDown)

hs.hotkey.bind(hyper, 'a', caffeineClicked)
hs.hotkey.bind(hyper, 'd', mouseHighlight)

-- Create and start our callbacks
hs.application.watcher.new(applicationWatcher):start()

screenWatcher = hs.screen.watcher.new(screensChangedCallback)
screenWatcher:start()
