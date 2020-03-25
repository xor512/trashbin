-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local battery_widget = require("awesome-wm-widgets.battery-widget.battery")
local hotkeys_popup = require("awful.hotkeys_popup").widget
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
--beautiful.init(awful.util.getdir("config") .. "themes/default/theme.lua")
beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")

-- This is used later as the default terminal and editor to run.
terminal = "xfce4-terminal"
--editor = os.getenv("EDITOR") or "nano"
editor = "gvim"
--editor_cmd = terminal .. " -e " .. editor
editor_cmd = editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

add_new_clients_as_slaves = false

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    -- awful.layout.suit.tile.left,
    -- awful.layout.suit.tile.bottom,
    -- awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    -- awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    -- awful.layout.suit.max,
    -- awful.layout.suit.max.fullscreen,
    -- awful.layout.suit.magnifier,
    -- awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Helper functions
local function client_menu_toggle_fn()
    local instance = nil

    return function ()
        if instance and instance.wibox.visible then
            instance:hide()
            instance = nil
        else
            instance = awful.menu.clients({ theme = { width = 250 } })
        end
    end
end
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end },
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "dmenu_run", function() awful.util.spawn("dmenu_run") end },
                                    { "open terminal", terminal },
                                  }
                        })

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- {{{ Wibar
-- Create a textclock widget
mytextclock = wibox.widget.textclock()
local cal_notification
mytextclock:connect_signal("button::release",
    function()
        if cal_notification == nil then
            awful.spawn.easy_async([[bash -c "ncal -3 -s PL -M -b | sed 's/_.\(.\)/+\1-/g'"]],
                function(stdout, stderr, reason, exit_code)
                    cal_notification = naughty.notify{
                        text = string.gsub(string.gsub(stdout, 
                                                       "+", "<span foreground='red'>"), 
                                                       "-", "</span>"),
                        font = "Roboto Mono Light for Powerline Bold 8",
                        timeout = 0,
                        width = auto,
                        destroy = function() cal_notification = nil end
                    }
                end
            )
        else
            naughty.destroy(cal_notification)
        end
    end)

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, client_menu_toggle_fn()),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    local lo = awful.layout.layouts
    local tags = {
        names  = { "float1", "float2", "tile3", "fair4", "tile5" },
        layout = { lo[1],    lo[1],    lo[2],   lo[3],   lo[2] }
    }
    awful.tag(tags.names, s, tags.layout)

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons
    }

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons
    }

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            mylauncher,
            s.mytaglist,
            s.mypromptbox,
        },
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            mykeyboardlayout,
            wibox.widget.systray(),
            battery_widget(),
            mytextclock,
            s.mylayoutbox,
        },
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    --awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
    --          {description = "go back", group = "tag"}),
    awful.key({ modkey,           }, "Escape",
        function ()
            -- If you want to always position the menu on the same place set coordinates
            --awful.menu.menu_keys.down = { "Down", "Alt_L" }
            awful.menu.clients({theme = { width = 250 }}, { keygrabber=true, coords={x=525, y=330} })
        end,
        {description = "application switcher (as right clicking on taskbar)", group = "awesome"}
    ),
    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "next window to the left by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(1)
        end,
        {description = "next window to the right by index", group = "client"}
    ),

    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey, "Control"   }, "m",      
        function ()
            for _, c in ipairs(mouse.screen.selected_tag:clients()) do
                 c.minimized = true
            end
        end,
              {description = "minimize all windows in current tag", group = "client"}),
    --- TODO: maximizing all windows this way does not work, it is here for future "maybe'make it working'
    awful.key({ modkey, "Control"   }, "u",      
        function ()
            for _, c in ipairs(mouse.screen.selected_tag:clients()) do
                 c.minimized = false
                 ---c:emit_signal(
                 ---    "request::activate", "key.unminimize", {raise = true}
                 ---)
            end
        end,
              {description = "maximize all windows in current tag", group = "client"}),
    awful.key({ modkey, "Control"   }, "c",      
        function ()
            for _, c in ipairs(mouse.screen.selected_tag:clients()) do
                 c:kill()
            end
        end,
              {description = "close all windows in current tag", group = "client"}),
    awful.key({ modkey, "Control" }, "Next", function (c) c:relative_move( 20,  20, -40, -40) end),
    awful.key({ modkey, "Control" }, "Prior", function (c) c:relative_move(-20, -20,  40,  40) end),
    awful.key({ modkey, "Control" }, "Down",  function (c) c:relative_move(  0,  20,   0,   0) end),
    awful.key({ modkey, "Control" }, "Up",    function (c) c:relative_move(  0, -20,   0,   0) end),
    awful.key({ modkey, "Control" }, "Left",  function (c) c:relative_move(-20,   0,   0,   0) end),
    awful.key({ modkey, "Control" }, "Right", function (c) c:relative_move( 20,   0,   0,   0) end),
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
)

-- Set keys
globalkeys = awful.util.table.join(globalkeys,
    awful.key({ modkey, "Control" }, "o", function ()
        awful.util.spawn("sync")
        awful.util.spawn("xautolock -locknow")
    end,
    {description = "lock screen", group = "custom"}),
    awful.key({ modkey, "Control" }, "t", function () awful.spawn.with_shell("~/bin/touchpadoff 1") end,
    {description = "disable touchpad", group = "custom"}),
    awful.key({ modkey, "Control" }, "y", function () awful.spawn.with_shell("~/bin/monitoroff") end,
    {description = "disable monitor", group = "custom"}),
    awful.key({                   }, "Print", function () awful.util.spawn("scrot -e 'mv $f ~/screenshots/ 2>/dev/null'", false) end,
    {description = "make screenshot and put it to ~/screenshots", group = "custom"}),
    awful.key({ modkey,           }, "Print", function () awful.spawn.with_shell("sleep 0.5 && scrot -s -e 'mv $f ~/screenshots/ 2>/dev/null'") end,
    {description = "make screenshot of area and put it to ~/screenshots", group = "custom"})
)
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     --- Firefox will start maximized next time if it was maximized
                     --- peviously and this will imply floating mode
                     maximized_vertical   = false,
                     maximized_horizontal = false,
                     --- remove gaps between windows
                     size_hints_honor = false,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
      },
      callback = add_new_clients_as_slaves and awful.client.setslave or nil
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
          "pinentry",
        },
        class = {
          "ReText",
          "Wicd-client.py",
          "VirtualBox",
          "Arandr",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
          "Wpa_gui",
          "pinentry",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here.
        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "ConfigManager",  -- Thunderbird's about:config.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true } },

    { rule_any = {
        class = { "Meld" }
    }, properties = { floating = true,
                      maximized_vertical   = true,
                      maximized_horizontal = true
       }
     },

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    { rule = { class = "Lxmusic" },
      properties = { screen = 1, tag = "tile5" } },
    { rule = { class = "Deadbeef" },
      properties = { screen = 1, tag = "tile5" } },
    { rule = { class = "Audacious" },
      properties = { screen = 1, tag = "tile5" } },
    { rule = { class = "Pavucontrol" },
      properties = { screen = 1, tag = "tile5" } },
    { rule = { class = "HipChat" },
      properties = { screen = 1, tag = "float1", floating = true } },
    { rule = { class = "Skype" },
      properties = { screen = 1, tag = "float1", floating = true } },
    { rule = { class = "Sky" },
      properties = { screen = 1, tag = "float1", floating = true } },
    { rule = { class = "Evolution" },
      properties = { screen = 1, tag = "float1", floating = true } },
    { rule = { class = "Thunderbird" },
      properties = { screen = 1, tag = "float1", floating = true } },
    { rule = { class = "Opera" },
      properties = { screen = 1, tag = "float1", floating = true } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    -- TODO: remove { rase = true } as per https://github.com/awesomeWM/awesome/issues/2594#issuecomment-455727093
    c:emit_signal("request::activate", "mouse_enter", { raise = false })
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

-- {{{ Autostart
local function isrunning(pname)
    local fpid = io.popen("pgrep -u " .. os.getenv("USER") .. " -o " .. pname)
    local pid = fpid:read("*n")
    fpid:close()

    if pid == nil or pid == "" then
        return false
    end

    return true
end

local function spawn_with_shell_once(pname, cmd)
    if not cmd then
        cmd = pname
    end
    if not isrunning(pname) then
        awful.spawn.with_shell(cmd)
    end
end

local function kill_with_shell(pname)
    if isrunning(pname) then
        awful.spawn.with_shell("pkill -9 " .. pname)
        os.execute("sleep 1")
    end
end

local function respawn_with_shell(pname, cmd)
    kill_with_shell(pname)
    if not cmd then
        cmd = pname
    end
    awful.spawn.with_shell(cmd)
end 

local function spawn(pname, cmd, once, sn_rules)
    if not cmd then
        cmd = pname
    end

    if not (once and isrunning(pname)) then
        awful.spawn(cmd, sn_rules)
    end
end

local function respawn(pname, cmd, sn_rules)
    kill_with_shell(pname)
    spawn(pname, cmd, false, sn_rules)
end

local function spawn_once(pname, cmd, sn_rules)
    if not cmd then
        cmd = pname
    end

    spawn(cmd, pname, true, sn_rules)
end

local function file_exists(name)
    local f = io.open(name,"r")
    if f == nil then
        return false
    end
    io.close(f)
    return true
end

-- TODO: need to restart right after that to get correct if have >1 monitors
--       number of screeens, tried with file guards and awesome_restart()
--       first time running startx but it didn't work
if file_exists("~/.screenlayout/layout.sh") then
    awful.spawn.with_shell("~/.screenlayout/layout.sh")
end

awful.spawn.with_shell("xset -b")
awful.spawn.with_shell("numlockx off")
awful.spawn.with_shell("xbacklight -set 70d")
respawn_with_shell("xautolock", "xautolock -detectsleep -time 10 -notify 30 -notifier \"notify-send -u critical -t 10000 -- 'LOCKING screen in 30 seconds'\" -locker 'i3lock-fancy -g -n' &")
--- TODO: wicd-gtk adds /etc/xdg/autostart/wicd-tray.desktop which does the same thing
--       but it seems not to work, find out why
-- respawn_with_shell("wicd-client", "wicd-client --tray &")
--spawn_once("xpad")

--spawn_once("thunderbird")
-- respawn("birdtray") -- TODO: doesn't work
----- spawn_once("davmail")
----- spawn_once("evolution")
--spawn_once("skypeforlinux")
--spawn_once("hipchat4")

spawn_once("pavucontrol")
--spawn_once("audacious")
spawn_once("deadbeef") -- audacious can not into APE
spawn_once("nm-applet")
spawn_once("xpad --hide --toggle")

--As we have only 2.6Gb of mememory we prefer opera over firefox
--spawn_once("firefox", "firefox", {
--    floating = true,
--    tag = "float1",
--    maximized_vertical   = true,
--    maximized_horizontal = false
--})

kill_with_shell("xfce4-terminal")
for i=1,4 do
    spawn("xfce4-terminal", "xfce4-terminal", false, {
        floating = false,
        screen = 1,
        tag = "fair4",
        maximized_vertical   = false,
        maximized_horizontal = false
    })
end

-- }}}

