# Smooth Scroll / Mouse++

Mouse++ is a small macOS menu bar app that turns stepped mouse-wheel input into smooth, trackpad-like scrolling.

## Requirements

- macOS 13 or newer.
- Xcode command line tools with Swift Package Manager:

```zsh
xcode-select --install
```

- An SVG renderer for the app icon. Install one of these:

```zsh
brew install librsvg
```

or:

```zsh
brew install imagemagick
```

## Install

From this source folder:

```zsh
./install.sh
```

The installer:

- Builds the release binary with `swift build -c release`.
- Creates `dist/Mouse++.app`.
- Signs the app with the first available Apple Development identity, or ad-hoc signing if none is found.
- Installs the app to `~/Applications/Mouse++.app` by default.
- Replaces an older `Smooth Scroll.app` in the same install directory.
- Opens the installed app.

To install somewhere else:

```zsh
SMOOTH_SCROLL_INSTALL_DIR="/Applications" ./install.sh
```

To build/install without opening the app:

```zsh
SMOOTH_SCROLL_SKIP_OPEN=1 ./install.sh
```

To force a signing identity:

```zsh
SMOOTH_SCROLL_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./install.sh
```

## First Run Permissions

Mouse++ needs macOS privacy permission to intercept wheel events.

1. Open Mouse++ from `~/Applications`.
2. Click the menu bar icon.
3. Open `Accessibility Settings...`.
4. Enable Mouse++ under Accessibility.
5. If the event tap still fails, also enable Mouse++ under Input Monitoring.
6. Quit and reopen Mouse++ if macOS does not apply the permission immediately.

The app shows `Needs Accessibility` or `Event Tap Failed` in the menu bar tooltip when permission is missing.

## Launch at Login

Open Mouse++ settings from the menu bar and enable `Launch at Login`.

This writes a launch agent at:

```text
~/Library/LaunchAgents/com.local.SmoothScroll.plist
```

The launch agent points at the currently installed app bundle. If you reinstall to a different directory, open Mouse++ once and toggle Launch at Login again if needed.

## Updating

Run the installer again:

```zsh
./install.sh
```

Or use `Update Mouse++` from the app menu/About tab.

The in-app updater works because `install.sh` writes the source checkout path into the app bundle during install. Keep this repo folder available if you want `Update Mouse++` to keep working. If you move the repo, run `./install.sh` once from the new location.

Update logs are written to:

```text
~/Library/Logs/Mouse++/update.log
```

## Settings

- `Smoothness`: glide duration after a wheel tick.
- `Strength`: scroll distance per wheel tick.
- `Vertical` / `Horizontal`: axis-specific scaling.
- `Acceleration`: extra speed for faster wheel movement.
- `Precision`: modifier key for slower scrolling.
- `Boost`: modifier key for faster scrolling.
- `Bypass`: modifier key to pass raw wheel events through unchanged.
- `Excluded Apps`: app-specific passthrough list.

## Troubleshooting

If install fails with `Missing SVG renderer`, install `librsvg` or `imagemagick` with Homebrew.

If Mouse++ opens but does not affect scrolling, check Accessibility and Input Monitoring permissions.

If one app behaves badly, add it to `Excluded Apps` or use the configured Bypass modifier while scrolling in that app.
