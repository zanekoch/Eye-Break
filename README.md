# EyeBreak

EyeBreak is a native macOS menu bar app whose job is to interrupt your goblin-like screen trance before your eyeballs file a formal complaint.

It lives in the menu bar, nags you to look away from the computer, and then politely waits while you ignore it for a few seconds.

## Features

- Runs as a menu bar app with no Dock icon.
- Can launch automatically at login.
- Defaults to active hours from 8:00 AM to 8:00 PM.
- Sends a notification every 20 minutes by default.
- Lets you turn reminders off, snooze them, change the interval, and change the default snooze length from the menu bar.
- Ships with a custom eye app icon that is used for the app bundle and notification icon.
- Persists your settings in `UserDefaults`.

## Why This Exists

Because "I’ll rest my eyes in a minute" is one of the great recurring lies in modern computing.

EyeBreak defaults to a reasonable setup:

- active between `8:00 AM` and `8:00 PM`
- reminds you every `20 minutes`
- snoozes for `75 minutes` by default when you need to temporarily re-enter productivity jail

## Build It

```bash
cd /Users/zane/Desktop/EyeBreak
./scripts/build-app.sh
```

This produces:

```text
/Users/zane/Desktop/EyeBreak/dist/EyeBreak.app
```

## Install It

```bash
cd /Users/zane/Desktop/EyeBreak
./scripts/install-app.sh
```

This copies the app into:

```text
/Users/zane/Applications/EyeBreak.app
```

## Run It

After installing, open `~/Applications/EyeBreak.app`.

On first launch macOS will ask for notification permission, which is important because EyeBreak’s entire personality is "tiny eye in menu bar, mildly judging your habits."

## Menu Bar Controls

From the menu bar you can:

- turn reminders on or off
- trigger `Remind Now`
- snooze reminders
- change the reminder interval
- change the default snooze length
- change the daily active hours
- enable launch at login

## Tech Notes

- Written in Swift with AppKit.
- Built with Swift Package Manager.
- Packaged into a standalone `.app` using the scripts in [`scripts/`](/Users/zane/Desktop/EyeBreak/scripts).

## License

Use it, change it, keep your eyes hydrated.
