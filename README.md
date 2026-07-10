<img width="1917" height="1079" alt="Screenshot 2026-07-10 201004" src="https://github.com/user-attachments/assets/458e17e9-27d0-481d-8f15-b702ee197f8e" />
<img width="1919" height="1079" alt="Screenshot 2026-07-10 200926" src="https://github.com/user-attachments/assets/cb0b5835-cb06-47a3-b659-711db6e37f03" />
<img width="1919" height="1079" alt="Screenshot 2026-07-10 200901" src="https://github.com/user-attachments/assets/f06dc671-e5e0-442c-bcde-dd41411a5561" />
# Syntax Frames

A cinematic "additional" camera that can be moved freely in the world, attached to
any npc/player/vehicle (dashcam-style), filtered, and used to grab clean screenshots
— great for car shots, promo shots and video. Custom NUI panel, fully keyboard-driven.

_Originally **Cinematic Cam** by kiminaze (Philipp Decker); renamed and reworked for Syntax._

## 📋 Features

- Toggle the free camera on/off; move and rotate on all axes (mouse + controller).
- Precise rotation, field-of-view and movement-speed control.
- ~700 timecycle **filters** with adjustable intensity — auto-cleared on close/exit.
- **Arrow-key navigation** of the whole panel (see Controls).
- **One-click screenshot** of the current scene → posted to Discord.
- Attach the camera to any npc/player/vehicle entity; free-fly and character-control modes.
- Toggle minimap on/off.
- Optional support for the [OrbitCam](https://github.com/Kiminaze/OrbitCam) resource.
- Optional ace-permission gating.

## 🎮 Controls

**Menu (NUI panel)**

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move between rows |
| `←` / `→` | Adjust slider / cycle dropdown / flip toggle |
| `Enter` | Activate button / flip toggle |
| `Backspace` / `DEL` / `Esc` | Close the panel |

The mouse still works too, and `WASD` / `SPACE` / `CTRL` / `Q` / `E` keep flying the
camera while the panel is open.

## ⚙️ Requirements

- [`ox_lib`](https://github.com/overextended/ox_lib) — notifications.
- [`screencapture`](https://github.com/) (provides `screenshot-basic`) — the screenshot button.
- Optional: [`OrbitCam`](https://github.com/Kiminaze/OrbitCam).

## 📷 Screenshot setup

The screenshot button uploads the captured frame to a **Discord webhook**. The webhook
URL is read server-side from a convar so it never reaches clients. Add this to your
`server.cfg` (use `set`, **not** `setr`):

```cfg
set syntax_frames:webhook "https://discord.com/api/webhooks/XXXXXXXX/YYYYYYYY"
```

Toggle the button on/off in `config.lua` via `Config.screenshot.enable`.

## 🔑 Permissions (optional)

- Set `Config.usePermissions = true` in `config.lua`.
- Add an ace named `"CinematicCamPermission"` in your `server.cfg`, e.g.
  `add_ace identifier.license:rockstarlicensehere "CinematicCamPermission" allow`
  (see `server/permission.lua`).

## 🚪 How players open it

- Chat command: `/cam` (toggles the panel) — `Config.command`.
- ox_inventory `camera` item (`export = 'syntax_frames.useCamera'`, `consume = 0`).
- Button/keybind: `Config.useButton`.

## ❓ Original support

https://discord.kiminaze.de
