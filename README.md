# Scrollercoaster

A macOS menu bar app that automatically applies the right scroll direction depending on your input device.

- **Trackpad / Magic Mouse** → natural scrolling (content follows your finger)
- **Regular mouse** → traditional scrolling (scroll wheel up moves content up)

macOS only has one global scroll direction setting, so this is otherwise impossible to configure natively.

## How it works

Scrollercoaster intercepts scroll events system-wide using a `CGEventTap` at the hardware (HID) level. Events from trackpads and Magic Mice carry a non-zero scroll phase or momentum phase that regular mice never set — that's how it tells them apart. Regular mouse scroll events are flipped; everything else passes through untouched.

## Features

- **Automatic per-device scroll direction** — no manual switching needed
- **Disable Scroll Acceleration** — replaces macOS's acceleration curve with a fixed, linear scroll speed for regular mice. Each notch of the scroll wheel always scrolls the same amount regardless of how fast you spin it.
- **Adjustable scroll speed** — when acceleration is disabled, a slider (1–100) lets you dial in exactly how much each notch scrolls. You can drag the slider or click the number and type a value directly.

## Requirements

- macOS 12 or later
- macOS 13 or later for Start at Login support
- **Natural Scrolling must be ON** in System Settings → Mouse (and Trackpad)
- Accessibility permission (the app will prompt on first launch)

## Build

Generate the app icon once:

```bash
swift make-icon.swift && iconutil -c icns AppIcon.iconset -o AppIcon.icns && rm -rf AppIcon.iconset
```

Then build the app:

```bash
./build.sh
```

This compiles the binary and assembles `Scrollercoaster.app` in the project directory.

> **Note:** After each rebuild you need to quit and reopen the app once, as macOS requires a restart for updated accessibility permissions to take effect.

## Install

```bash
cp -r Scrollercoaster.app ~/Applications/
open ~/Applications/Scrollercoaster.app
```

Grant Accessibility access when prompted, then quit and reopen the app. It runs in the background with no dock icon — look for the mouse icon in your menu bar.

## Usage

Click the menu bar icon to access:

- **Disable Scroll Acceleration** — toggle to enable linear scrolling for regular mice
  - **Speed slider** — drag or type a value (1–100) to set how much each scroll notch moves; only active when acceleration is disabled
- **Start at Login** — toggle to have Scrollercoaster launch automatically on login
- **Hide Menu Bar Icon** — toggle to remove the icon from the menu bar. While hidden, opening `Scrollercoaster.app` again (even if it's already running) pops the menu up automatically so you can turn the icon back on or change settings.
- **Quit** — stop the app

If Natural Scrolling is turned off in System Settings, a warning will appear in the menu linking you to the relevant settings pane.

## Uninstall

1. Disable Start at Login via the menu bar (if enabled)
2. Remove Accessibility permission in System Settings → Privacy & Security → Accessibility
3. Delete the app
