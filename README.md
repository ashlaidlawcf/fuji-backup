# Fuji Backup

A small Mac app (Apple silicon, macOS 14 or later) that backs up and restores a Fujifilm camera's settings over USB. That includes custom settings C1–C7. It saves the same `.DAT` file Fujifilm's X Acquire makes, and has nothing else in it.

## Use

1. On the camera: **SET UP › CONNECTION SETTING › PC CONNECTION MODE › USB RAW CONV./BACKUP RESTORE**.
2. Connect the camera by USB and open Fuji Backup.
3. **Back Up** (⌘B) saves a backup to `~/Documents/Fuji Backups`, named like `X-T3 5.11 2026-11-21 143012.dat`.
4. To restore, hover over a backup and click **Restore…**, or use **Restore from File…** in the toolbar.

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

The camera rejects a read and a write in one session, so each runs in a session of its own. The protocol details come from community reverse-engineering: [fujifilm-ptp-reference](https://github.com/zgrimz/fujifilm-ptp-reference), [grawji](https://github.com/p5k369/grawji) and [libfuji](https://github.com/petabyt/libfuji). This is not a Fujifilm product.

## Tested

| What | Evidence |
| --- | --- |
| PTP packet building and parsing, backup-file checks | unit tests |
| Interface states | rendered on a Mac without a camera |
| Backup and restore on a camera | **not yet** |

## Debug builds

`FUJIBACKUP_DEMO=ready|searching|wrongmode|empty` shows sample states without a camera, and `FUJIBACKUP_SNAPSHOT=<file.png>` saves the window as a picture and quits. Both work only in debug builds (`swift build`).
