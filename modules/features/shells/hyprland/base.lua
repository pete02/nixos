
-- General settings
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 2,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    render {
        direct_scanout = 0
        cm_enabled = 0
        send_content_type = 0
    },

    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },

        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },

    input = {
        kb_layout = "fi",
    },

    xwayland = {
        force_zero_scaling = true,
    },

    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },

    debug = {
        full_cm_proto = true,
        disable_logs = false,
    },
})

-- Startup
hl.on("hyprland.start", function()
    hl.exec_cmd("wayle shell")
    hl.exec_cmd(
        "systemctl --user import-environment " ..
        "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP " ..
        "HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE"
    )
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd " ..
        "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP " ..
        "HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE"
    )
end)

-- Application and window management
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("rofi -show drun -show-icons"))
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + M", hl.dsp.exit())
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + UP", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen())

-- Workspace navigation
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Screenshot
hl.bind("SUPER + P", hl.dsp.exec_cmd(
    [[bash -c 'mkdir -p ~/screenshots; SCREENSHOT="$HOME/screenshots/$(date "+%Y-%m-%d_%H-%M-%S").png"; grim -g "$(slurp)" - | magick - -shave 1x1 PNG:- > "$SCREENSHOT" && wl-copy < "$SCREENSHOT"']]
))

-- Audio and media keys
hl.bind("XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })

hl.bind("XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })

hl.bind("XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, repeating = true })

hl.bind("XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true })

hl.bind("XF86AudioPlay",
    hl.dsp.exec_cmd("playerctl play-pause"),
    { locked = true, repeating = true })

-- Display brightness
hl.bind("XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
    { locked = true, repeating = true })

hl.bind("XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
    { locked = true, repeating = true })
