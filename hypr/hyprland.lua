-- Hyprland config: the same keys, ten tags on workspaces 1-10, window rules,
-- scratchpads, autostart and gaps, with the UI in the Quickshell bar.
local mod = "SUPER"
local smod = "SUPER + SHIFT"
local altkey = "ALT"

local termcmd = "alacritty"

local tag_border_focused = "rgba(FF59F9ff)"
local tag_border_normal = "rgba(434C5Eff)"

------------------
---- MONITORS ----
------------------

-- HDMI-A-1 at 2560x1440, as set in the river autostart. Change the name
-- to match your output (see `hyprctl monitors`).
hl.monitor(
    {
        output = "HDMI-A-1",
        mode = "2560x1440@59.951",
        position = "auto",
        scale = 1,
    }
)

-------------------
---- AUTOSTART ----
-------------------

hl.on(
    "hyprland.start", function()
        -- the bar, notifications and tray applets
        hl.exec_cmd("qs")
        -- KDE polkit agent, the KDE wallet
        hl.exec_cmd(
            "dex /etc/xdg/autostart/polkit-kde-authentication-agent-1.desktop"
        )
        hl.exec_cmd("/usr/lib/pam_kwallet_init")
        hl.exec_cmd("kwalletd6")
        hl.exec_cmd("nm-applet")
        hl.exec_cmd("blueman-applet")
        hl.exec_cmd("volctl")
        hl.exec_cmd("ckb-next --background")
        -- CachyOS update notifier, in the tray the bar shows
        hl.exec_cmd("arch-update --tray")
        -- the wallpaper, as river's autostart does
        hl.exec_cmd(
            "swaybg -i /usr/share/wallpapers/cachyos-wallpapers/cachygalaxy99.jpg -m fill"
        )
    end
)

-------------------------
---- ENVIRONMENT ----
-------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config(
    {
        general = {
            -- gaps = 10, both inside and outside
            gaps_in = 10,
            gaps_out = 10,
            border_size = 2,
            col = {
                active_border = tag_border_focused,
                inactive_border = tag_border_normal,
            },
            -- the layout you start with. Super+space toggles master and dwindle
            layout = "master",
            resize_on_border = false,
            allow_tearing = false,
        },
        decoration = {
            -- windows are square and flat
            rounding = 0,
            active_opacity = 1.0,
            inactive_opacity = 1.0,
            shadow = {
                enabled = false,
            },
            blur = {
                enabled = false,
            },
        },
        animations = {
            enabled = false,
        },
        master = {
            -- mfact = 0.5, and new windows go to the master area
            mfact = 0.5,
            new_status = "master",
        },
        dwindle = {
            preserve_split = true,
        },
        misc = {
            force_default_wallpaper = 0,
            disable_hyprland_logo = true,
            -- a terminal is replaced by the GUI app it launched, and comes back
            -- when that app exits (window swallowing)
            enable_swallow = true,
            swallow_regex = "^(Alacritty)$",
            swallow_exception_regex = "^(scratchpad_.*)$",
        },
    }
)

---------------
---- INPUT ----
---------------

hl.config(
    {
        input = {
            -- keyboard: gb, Caps Lock as Escape, numlock on
            kb_layout = "gb",
            kb_options = "caps:escape",
            numlock_by_default = true,
            follow_mouse = 1,
        },
    }
)

-----------------------
---- TITLE BARS ----
-----------------------

-- A bar on every window, from the hyprbars plugin (hyprpm, hyprland-plugins).
-- Colors and font follow Quickshell's Config.qml. The minimize button sends
-- the window to the dock (see Super+n and dock/Dock.qml).
-- The plugin has to load before its config keys exist.
hl.plugin.load("/var/cache/hyprpm/wayne/hyprland-plugins/hyprbars.so")

hl.config(
    {
        plugin = {
            hyprbars = {
                bar_height = 22,
                bar_color = "rgb(2E3440)",
                bar_text_font = "Hack Nerd Font",
                bar_text_size = 9,
                bar_text_align = "left",
                bar_part_of_window = true,
            },
        },
    }
)

-- close, then minimize: closes the window whose title bar it's on
hl.plugin.hyprbars.add_button(
    {
        bg_color = "rgb(CC3333)",
        fg_color = "rgb(283036)",
        size = 14,
        icon = "\u{f00d}",
        action = "qs ipc call window close",
    }
)

hl.plugin.hyprbars.add_button(
    {
        bg_color = "rgb(D4C94A)",
        fg_color = "rgb(283036)",
        size = 14,
        icon = "\u{f2d1}",
        action = "qs ipc call dock minimize",
    }
)

-- Super+t hides and shows the title bars. A reload brings them back.
local title_bars_shown = true
hl.bind(
    mod .. " + t", function()
        title_bars_shown = not title_bars_shown
        hl.config({ plugin = { hyprbars = { enabled = title_bars_shown } } })
    end, { description = "Toggle title bars" }
)

---------------------
---- KEYBINDINGS ----
---------------------

-- Each layout in the cycle. scrolling is left out. "|M|" is
-- the centered master: the master layout with its master area in the middle.
local layout_cycle = {
    { layout = "master", orientation = "left" },
    { layout = "dwindle" },
    { layout = "monocle" },
    { layout = "master", orientation = "center" },
}

local function toggle_layout()
    local current = hl.get_config("general.layout")
    local orientation = hl.get_config("master.orientation") or "left"
    local index = 0
    for i, entry in ipairs(layout_cycle) do
        if entry.layout == current and (entry.orientation or "left") == orientation then
            index = i
            break
        end
    end
    local nxt = layout_cycle[index % #layout_cycle + 1]
    hl.config(
        {
            general = {
                layout = nxt.layout,
            },
            master = {
                orientation = nxt.orientation or "left",
            },
        }
    )
end

-- the bar's layout label calls this through `hyprctl eval` when clicked
bar_toggle_layout = toggle_layout

-- Gaps: "h" is the top and bottom gap, "v" the left and right.
-- Each press changes them by gap_step pixels.
local gap_step = 1
local gaps = { in_h = 10, in_v = 10, out_h = 10, out_v = 10 }
local gaps_on = true

local function apply_gaps()
    local f = gaps_on and 1 or 0
    local function sides(h, v)
        return { top = h * f, right = v * f, bottom = h * f, left = v * f }
    end
    hl.config(
        {
            general = {
                gaps_in = sides(gaps.in_h, gaps.in_v),
                gaps_out = sides(gaps.out_h, gaps.out_v),
            },
        }
    )
end

-- changes the named gaps by delta, and turns gaps back on if they were toggled off
local function adjust_gaps(names, delta)
    gaps_on = true
    for _, name in ipairs(names) do
        gaps[name] = math.max(0, gaps[name] + delta)
    end
    apply_gaps()
end

local function toggle_gaps()
    gaps_on = not gaps_on
    apply_gaps()
end

local function reset_gaps()
    gaps = { in_h = 10, in_v = 10, out_h = 10, out_v = 10 }
    gaps_on = true
    apply_gaps()
end

local all_gaps = { "in_h", "in_v", "out_h", "out_v" }
local inner_gaps = { "in_h", "in_v" }

-- Layout messages only exist for some layouts. Sending master's message in
-- scrolling raises "no such layoutmsg", so each key sends the message for the
-- layout that's active, and does nothing in layouts that have no equivalent.
local function layout_key(by_layout)
    return function()
        local msg = by_layout[hl.get_config("general.layout")]
        if msg then
            hl.dispatch(hl.dsp.layout(msg))
        end
    end
end

-- focus / stack (master and scrolling)
hl.bind(mod .. " + j", layout_key({ master = "cyclenext", scrolling = "focus r" }), { description = "Focus next window" })
hl.bind(mod .. " + k", layout_key({ master = "cycleprev", scrolling = "focus l" }), { description = "Focus previous window" })
hl.bind(mod .. " + Tab", layout_key({ master = "cyclenext", scrolling = "focus r" }), { description = "Focus next window" })
hl.bind(smod .. " + j", layout_key({ master = "swapnext", scrolling = "swapcol r" }), { description = "Swap with next window" })
hl.bind(smod .. " + k", layout_key({ master = "swapprev", scrolling = "swapcol l" }), { description = "Swap with previous window" })
hl.bind(smod .. " + q", hl.dsp.window.close(), { description = "Close window" })
hl.bind(
    smod .. " + space", hl.dsp.window.float(
        {
            action = "toggle",
        }
    ), { description = "Toggle floating" }
)

-- layout / mfact / nmaster
hl.bind(mod .. " + space", toggle_layout, { description = "Cycle layout" })
hl.bind(mod .. " + ctrl + comma", toggle_layout, { description = "Cycle layout" })
hl.bind(mod .. " + ctrl + period", toggle_layout, { description = "Cycle layout" })
hl.bind(mod .. " + h", layout_key({ master = "mfact -0.05", scrolling = "colresize -conf" }), { description = "Shrink master or column" })
hl.bind(mod .. " + l", layout_key({ master = "mfact +0.05", scrolling = "colresize +conf" }), { description = "Grow master or column" })
hl.bind(mod .. " + i", layout_key({ master = "addmaster" }), { description = "Add window to master area" })
hl.bind(mod .. " + u", layout_key({ master = "removemaster" }), { description = "Remove window from master area" })

-- the window's share of its column (cfact), as a resize
hl.bind(
    smod .. " + h", hl.dsp.window.resize(
        {
            x = -100,
            y = 0,
            relative = true,
        }
    ), { description = "Shrink window width" }
)
hl.bind(
    smod .. " + l", hl.dsp.window.resize(
        {
            x = 100,
            y = 0,
            relative = true,
        }
    ), { description = "Grow window width" }
)

-- gaps: Shift+Super+U grows all gaps and Shift+Super+I grows the inner ones;
-- Super+Ctrl+Shift+U and Super+Ctrl+Shift+I shrink them again
hl.bind(mod .. " + g", toggle_gaps, { description = "Toggle gaps" })
hl.bind(smod .. " + u", function() adjust_gaps(all_gaps, gap_step) end, { description = "Grow all gaps" })
hl.bind(mod .. " + ctrl + shift + u", function() adjust_gaps(all_gaps, -gap_step) end, { description = "Shrink all gaps" })
hl.bind(smod .. " + i", function() adjust_gaps(inner_gaps, gap_step) end, { description = "Grow inner gaps" })
hl.bind(mod .. " + ctrl + shift + i", function() adjust_gaps(inner_gaps, -gap_step) end, { description = "Shrink inner gaps" })
hl.bind(mod .. " + ctrl + shift + d", reset_gaps, { description = "Reset gaps" })

-- screens / monitors
hl.bind(
    mod .. " + bracketright", hl.dsp.focus(
        {
            monitor = "+1",
        }
    ), { description = "Focus next monitor" }
)
hl.bind(
    mod .. " + bracketleft", hl.dsp.focus(
        {
            monitor = "-1",
        }
    ), { description = "Focus previous monitor" }
)
hl.bind(
    mod .. " + period", hl.dsp.focus(
        {
            monitor = "+1",
        }
    ), { description = "Focus next monitor" }
)
hl.bind(
    mod .. " + comma", hl.dsp.focus(
        {
            monitor = "-1",
        }
    ), { description = "Focus previous monitor" }
)
hl.bind(
    smod .. " + comma", hl.dsp.window.move(
        {
            monitor = "-1",
        }
    ), { description = "Move window to previous monitor" }
)
hl.bind(
    smod .. " + period", hl.dsp.window.move(
        {
            monitor = "+1",
        }
    ), { description = "Move window to next monitor" }
)

-- tags: Super+N views workspace N, Super+Shift+N moves the window there
-- and follows it, and Super+Alt+N moves it without following
for i, key in ipairs(
                  {
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "0",
    }
              ) do
    hl.bind(
        mod .. " + " .. key, hl.dsp.focus(
            {
                workspace = i,
            }
        ), { description = "Go to tag " .. i }
    )
    hl.bind(
        smod .. " + " .. key, hl.dsp.window.move(
            {
                workspace = i,
            }
        ), { description = "Move window to tag " .. i }
    )
    hl.bind(
        mod .. " + ALT + " .. key, hl.dsp.window.move(
            {
                workspace = i,
                follow = false,
            }
        ), { description = "Send window to tag " .. i .. " without following" }
    )
end

-- Scratchpads, Alt+Return and Alt+b. Each lives on a hidden workspace (90 and
-- 91) and is moved onto the workspace you're on when shown, so the windows
-- around it stay clickable. scratchpad.sh does the moving; it also starts the
-- scratchpad if it isn't running, so toggling always shows one.
local function toggle_scratchpad(class, hidden, cmd)
    hl.exec_cmd("sh $HOME/.config/hypr/scratchpad.sh " .. class .. " " .. hidden .. " " .. cmd)
end

hl.bind(
    altkey .. " + Return", function()
        toggle_scratchpad(
            "scratchpad_terminal",
            90,
            "alacritty --title=scratchpad_terminal --class=scratchpad_terminal,scratchpad_terminal"
        )
    end, { description = "Toggle terminal scratchpad" }
)
hl.bind(
    altkey .. " + b", function()
        toggle_scratchpad(
            "scratchpad_btop",
            91,
            "alacritty --class=scratchpad_btop,scratchpad_btop -e btop"
        )
    end, { description = "Toggle btop scratchpad" }
)

-- Minimize, Super+n: the focused window moves to the hidden workspace 98,
-- and the Quickshell dock (dock/Dock.qml) lists it. Clicking it there brings
-- it back to the workspace you're on. Keep the number in step with
-- Config.minimizedWorkspace in Quickshell.
local minimized_ws = 98
hl.bind(mod .. " + n", hl.dsp.window.move({ workspace = minimized_ws, follow = false }), { description = "Minimize window to dock" })

-- spawns
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(termcmd), { description = "Open terminal" })
hl.bind(smod .. " + Return", hl.dsp.exec_cmd("dolphin"), { description = "Open file manager" })
hl.bind(mod .. " + m", hl.dsp.exec_cmd("qs ipc call apps toggle"), { description = "App menu" })
hl.bind(mod .. " + F1", hl.dsp.exec_cmd("qs ipc call clipboard toggle"), { description = "Clipboard history" })
hl.bind(smod .. " + e", hl.dsp.exec_cmd("qs ipc call power toggle"), { description = "Power menu" })
hl.bind(mod .. " + ctrl + h", hl.dsp.exec_cmd("virtualbox"), { description = "Open VirtualBox" })
hl.bind(mod .. " + ctrl + b", hl.dsp.exec_cmd("google-chrome-stable"), { description = "Open Chrome" })
hl.bind(mod .. " + ctrl + e", hl.dsp.exec_cmd("code"), { description = "Open VS Code" })
hl.bind(mod .. " + ctrl + d", hl.dsp.exec_cmd("discord"), { description = "Open Discord" })
hl.bind(mod .. " + ctrl + p", hl.dsp.exec_cmd("pkgbrowser"), { description = "Open package browser" })
hl.bind(mod .. " + ALT + p", hl.dsp.exec_cmd("piper"), { description = "Open Piper" })
hl.bind(mod .. " + ALT + s", hl.dsp.exec_cmd("steam"), { description = "Open Steam" })
hl.bind(mod .. " + ALT + m", hl.dsp.exec_cmd("minecraft-launcher"), { description = "Open Minecraft launcher" })
hl.bind(mod .. " + ALT + r", hl.dsp.exec_cmd("jagex-launcher"), { description = "Open Jagex launcher" })

-- screenshots are Quickshell's (screenshot/Screenshot.qml), saved to
-- ~/Pictures/Screenshots and copied to the clipboard
hl.bind("Print", hl.dsp.exec_cmd("qs ipc call screenshot region"), { description = "Screenshot a region" })
hl.bind("ctrl + Print", hl.dsp.exec_cmd("qs ipc call screenshot full"), { description = "Screenshot the screen" })
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("qs ipc call screenshot window"), { description = "Screenshot a window" })

-- media keys
hl.bind(
    "XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), {
        locked = true,
        repeating = true,
        description = "Brightness up",
    }
)
hl.bind(
    "XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), {
        locked = true,
        repeating = true,
        description = "Brightness down",
    }
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), {
        locked = true,
        repeating = true,
        description = "Volume down",
    }
)
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), {
        locked = true,
        repeating = true,
        description = "Volume up",
    }
)
hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), {
        locked = true,
        repeating = true,
        description = "Mute audio",
    }
)
hl.bind(
    "XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), {
        locked = true,
        description = "Play or pause media",
    }
)
hl.bind(
    "XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), {
        locked = true,
        description = "Play or pause media",
    }
)
hl.bind(
    "XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), {
        locked = true,
        description = "Next track",
    }
)
hl.bind(
    "XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), {
        locked = true,
        description = "Previous track",
    }
)

-- the bar (Quickshell): toggle it, and the hotkeys popup
hl.bind(mod .. " + b", hl.dsp.exec_cmd("qs ipc call bar toggle"), { description = "Toggle top bar" })
hl.bind(mod .. " + w", hl.dsp.exec_cmd("qs ipc call tags toggle"), { description = "Hide or show empty tags" })
hl.bind(mod .. " + slash", hl.dsp.exec_cmd("qs ipc call hotkeys toggle"), { description = "Show this hotkeys list" })

-- session: quit, and restart (reloads this file; windows survive)
hl.bind(smod .. " + r", hl.dsp.exit(), { description = "Quit Hyprland" })
-- Ctrl+Alt+R moves open windows to their tags, restarts the Quickshell bar
-- and reloads this file, so edits take effect. Open windows survive.
hl.bind(
    "ALT + ctrl + r", function()
        place_windows()
        hl.exec_cmd("sh -c 'pkill -x qs; sleep 0.5; setsid qs'")
        hl.dispatch(hl.dsp.reload_config())
    end, { description = "Reload config and restart shell" }
)

-- mouse: Super + drag moves, Super + right drag resizes, Super + middle
-- click toggles floating (the mouse window bindings)
hl.bind(
    mod .. " + mouse:272", hl.dsp.window.drag(), {
        mouse = true,
        description = "Move window with mouse",
    }
)
hl.bind(
    mod .. " + mouse:273", hl.dsp.window.resize(), {
        mouse = true,
        description = "Resize window with mouse",
    }
)
hl.bind(
    mod .. " + mouse:274", hl.dsp.window.float(
        {
            action = "toggle",
        }
    ), { description = "Toggle floating with mouse" }
)

----------------------------
---- WINDOWS AND TAGS ----
----------------------------

hl.window_rule(
    {
        name = "suppress-maximize",
        match = {
            class = ".*",
        },
        suppress_event = "maximize",
    }
)

-- tag assignment, as in the window rules: each app opens on its tag.
-- `classes` and `titles` are exact names; any one of them matches.
tag_rules = {
    {
        classes = {
            "Alacritty",
        },
        tag = 1,
    },
    {
        classes = {
            "Code",
            "com.microsoft.VSCode",
        },
        tag = 2,
    },
    {
        classes = {
            "android-studio",
        },
        tag = 2,
    },
    {
        classes = {
            "org.kde.dolphin",
        },
        tag = 3,
    },
    {
        classes = {
            "Gimp",
        },
        tag = 4,
    },
    {
        classes = {
            "firefox",
        },
        tag = 6,
    },
    -- Chrome's Wayland class is lowercase; the capitalised one is its X11 class
    {
        classes = {
            "google-chrome",
            "Google-chrome",
        },
        tag = 6,
    },
    -- Steam's client is class "steam"; its games are "steam_app_<id>"
    {
        classes = {
            "steam",
        },
        tag = 7,
    },
    {
        classes = {
            "jagex-launcher",
        },
        tag = 8,
    },
    {
        classes = {
            "discord",
        },
        tag = 9,
    },
    {
        titles = {
            "Event Tester",
            "lazygit",
        },
        tag = 10,
    },
}

local function alternatives(names)
    return "^(" .. table.concat(names, "|") .. ")$"
end

for _, r in ipairs(tag_rules) do
    local match = {}
    if r.classes then
        match.class = alternatives(r.classes)
    end
    if r.titles then
        match.title = alternatives(r.titles)
    end
    hl.window_rule(
        {
            name = "tag-" .. (r.classes and r.classes[1] or r.titles[1]),
            match = match,
            workspace = tostring(r.tag),
        }
    )
end

-- the tag a window belongs on, or nil if no rule covers it
local function tag_for(class, title)
    for _, r in ipairs(tag_rules) do
        for _, c in ipairs(r.classes or {}) do
            if c == class then
                return r.tag
            end
        end
        for _, t in ipairs(r.titles or {}) do
            if t == title then
                return r.tag
            end
        end
    end
    return nil
end

-- Rules only apply to windows as they open. This moves the windows that are
-- already open to their tags (without changing the workspace you're on).
-- Ctrl+Alt+R calls it on reload. Minimized windows stay minimized.
function place_windows()
    for _, w in ipairs(hl.get_windows()) do
        local target = tag_for(w.class, w.title)
        if target and w.workspace and w.workspace.id ~= target and
            w.workspace.id ~= minimized_ws and not w.floating then
            hl.dispatch(
                hl.dsp.window.move(
                    {
                        workspace = target,
                        follow = false,
                        window = "address:" .. w.address,
                    }
                )
            )
        end
    end
end

-- float-only apps, as in the floating rules (they stay on the tag
-- they open on)
for _, class in ipairs(
                    {
        "^Yad$",
        "^Peek$",
        "^Snapper$",
        "^plasma.emojier$",
    }
                ) do
    hl.window_rule(
        {
            name = "float-" .. class,
            match = {
                class = class,
            },
            float = true,
        }
    )
end

-- scratchpads: their windows go straight to their special workspace, float,
-- and are centered at half the screen's width and height
hl.window_rule(
    {
        name = "scratchpad-terminal",
        match = {
            class = "^scratchpad_terminal$",
        },
        workspace = "90 silent",
        float = true,
        size = "monitor_w*0.5 monitor_h*0.5",
        center = true,
    }
)
hl.window_rule(
    {
        name = "scratchpad-btop",
        match = {
            class = "^scratchpad_btop$",
        },
        workspace = "91 silent",
        float = true,
        size = "monitor_w*0.5 monitor_h*0.5",
        center = true,
    }
)
