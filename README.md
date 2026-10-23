# Edge Glow

Superwhisper's recording glow along the bottom edge of the screen, driven by
whatever is playing on your default speaker output. It never opens the
microphone, so no dictation is started and nothing is transcribed or pasted.

The glow follows the music's spectrum (via `cava`), so it moves with the bass and
the highs instead of just getting louder and quieter.

## Features

- Speaker-driven Superwhisper `edgeGlow`, drawn along the bottom of the focused
  monitor.
- Never touches the microphone — only the default sink's monitor source.
- Show it always, or only while the focused workspace has no windows.
- Intensity control from 0% (invisible) to 200% (twice as bright).
- Native Omarchy bar widget and panel, styled like the built-in Display panel.
- Settings persist across shell restarts.

## Requirements

- Omarchy with the Quattro shell (Quickshell).
- Hyprland (`hyprctl`).
- `cava` — `sudo pacman -S cava` if it is not installed.
- Superwhisper, with its indicator at `/opt/superwhisper/bin/superwhisper-indicator`.
- Unprivileged user namespaces enabled (the preview fakes Hyprland's active
  window in a private namespace to keep the indicator off your real windows).

## Install

```sh
omarchy plugin add https://github.com/abdxdev/omarchy-edge-glow.git --enable
```

The widget is added to the right side of the bar by default.

## Usage

- **Left-click** the wave icon to open the panel.
- **Right-click** the wave icon to turn the preview on or off.
- **Show on** — `Always` draws the glow on every workspace, `Only when empty`
  draws it only while the focused workspace has no windows.
- **Intensity** — drag the slider from 0% to 200%. The default is 100%.
- Click anywhere outside the panel to close it.

The icon is dimmed while the preview is off.

## Command line

The panel and the preview share one state, also reachable over IPC:

```sh
omarchy-shell abdxdev.edge-glow status
omarchy-shell abdxdev.edge-glow toggle
omarchy-shell abdxdev.edge-glow enable
omarchy-shell abdxdev.edge-glow disable
omarchy-shell abdxdev.edge-glow showAlways
omarchy-shell abdxdev.edge-glow showOnEmpty
omarchy-shell abdxdev.edge-glow brighter
omarchy-shell abdxdev.edge-glow dimmer
omarchy-shell abdxdev.edge-glow resetIntensity
```

Settings live in `~/.local/state/omarchy/edge-glow.json`.

## How it works

The bundled `bin/superwhisper-glow-preview-speaker` script runs Superwhisper's
indicator in a throwaway user/mount namespace, feeds it 24 `cava` bars from the
default sink's monitor, and keeps the indicator's fake "active window" alive so
the glow is drawn. It never records audio and never opens a microphone.

The plugin itself only owns the lifecycle (start/stop/restart) and the settings.
The preview script supports the same options directly:

```sh
./bin/superwhisper-glow-preview-speaker 5 edgeGlow --mode always --intensity 100
```

## Remove

```sh
omarchy plugin remove io.github.abdxdev.edge-glow
```

## License

MIT
