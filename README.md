# Fuji Backup

A small Mac app (Apple silicon, macOS 14 or later) that backs up and restores a Fujifilm camera's settings over USB. That includes custom settings C1–C7. It saves the same `.DAT` file Fujifilm's X Acquire makes, and has nothing else in it.

## Use

1. On the camera: **SET UP › CONNECTION SETTING › PC CONNECTION MODE › USB RAW CONV./BACKUP RESTORE**.
2. Connect the camera by USB and open Fuji Backup.
3. **Back Up** (⌘B) saves a backup to `~/Documents/Fuji Backups`, named like `X-T3 5.11 2026-11-21 143012.dat`.
4. To see the recipes in a backup (C1–C7), hover over it and click the recipes button, or double-click it. Each recipe has a copy button that copies it as text. This works for X-T3 backups for now.
5. To restore, hover over a backup and click the restore button, or use **Restore from File…** in the toolbar.
6. To delete a backup, hover over it and click the trash button, or select it and press Delete, then confirm. It goes to the Trash.

Before writing anything, a restore:
- reads the camera's current settings and saves them as a new backup, so you can undo;
- refuses a backup from another model, or another firmware version when the file name records it, or one whose size differs from the camera's own backup.

Backups hold the camera's serial number. Keep them private.

## Build

```sh
./scripts/build-app.sh          # -> build/Fuji Backup.app (ad-hoc signed)
swift test                      # unit tests: PTP packets, device info, backup checks
```

Needs Xcode 16 or later (Swift 6). No dependencies: it uses macOS's ImageCaptureCore to send PTP commands.

## How it works

Backup and restore are standard PTP operations on object handle 0, which the camera offers only in USB RAW CONV./BACKUP RESTORE mode (Fujifilm property 0xD16E = 6):

| Step | PTP |
| --- | --- |
| Back up | GetObjectInfo(0), GetObject(0) |
| Restore | SendObjectInfo(0, 0) with a 1076-byte ObjectInfo (format 0x5000, the file's size, zeros), then SendObject |

The camera rejects a read and a write in one session, so each runs in a session of its own. The protocol details come from community reverse-engineering (see [Credits](#credits)).

## Reading recipes

Each custom setting is a 256-byte record in the backup (X-T3: C1 at 0x7B7C, then every 0x100). Positions and codes come from three places that agree with each other:

| Field | Source |
| --- | --- |
| Positions of every field | the X-T3 5.11 firmware's custom-setting code; also matches [grawji](https://github.com/p5k369/grawji)'s hardware diffs |
| Film simulation, white balance, Kelvin, dynamic range, colour, sharpness | the firmware's own value-name tables (BKUP_FILM_SIM_*, BKUP_WB_*, …) |
| Highlight, shadow, noise reduction, grain, Color Chrome | grawji's hardware diffs; the camera's default values fit |

Official firmware doesn't save the white balance shift with a custom setting (one shift per white balance mode is shared by all of them), so recipes show no shift. A value the app doesn't recognise is shown as its code.

## Tested

| What | Evidence |
| --- | --- |
| PTP packet building and parsing, backup-file checks, recipe decoding | unit tests |
| Interface states | rendered on a Mac without a camera |
| Backup and restore on an X-T3 | camera |
| Recipes read from a real X-T3 backup | names and values plausible; not yet checked setting by setting against the camera |

## Credits

Fuji Backup stands on other people's reverse-engineering. Thank you to:

- **[fujifilm-ptp-reference](https://github.com/zgrimz/fujifilm-ptp-reference)** by Zachary Grimshaw: a clear, tested reference for Fujifilm's USB protocol. It's where this app learned about backup mode (property 0xD16E), the backup and restore sequence, and the backup file's header.
- **[grawji](https://github.com/p5k369/grawji)**: the restore details (the 1076-byte ObjectInfo, separate sessions for reading and writing) and the X-T3 backup layout, worked out from controlled backups on real cameras. Its findings on where each recipe setting lives, and on how highlight, shadow, noise reduction, grain and Color Chrome are stored, made the recipe view possible.
- **[libfuji](https://github.com/petabyt/libfuji)** by petabyt: an open implementation of Fujifilm's USB features, including settings backup and restore, that confirmed the sequence.

No code was copied from these projects. This app uses their published findings, checked against the X-T3's own firmware where possible.

The app has no third-party dependencies. It is built with Apple's Swift, SwiftUI and ImageCaptureCore.

Fujifilm, X-T3 and X Acquire are Fujifilm's. This project is not affiliated with Fujifilm.

## Debug builds

`FUJIBACKUP_DEMO=ready|searching|wrongmode|empty` shows sample states without a camera and never looks for one; `FUJIBACKUP_DEMO_FROM=<folder>` uses copies of real backups. `FUJIBACKUP_SNAPSHOT=<file.png>` saves the window as a picture, and `FUJIBACKUP_CHECK=notice|restore-prompt|recipes` runs one interface check. All are debug-build only (`swift build`).
