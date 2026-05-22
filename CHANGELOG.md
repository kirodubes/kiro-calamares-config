# CHANGELOG — kiro-calamares-config

> Calamares graphical installer configuration. Custom Python modules: `kiro_before`, `kiro_final`, `kiro_remove_nvidia`, `kiro_ucode`.

---

## 2026-05-22 — Silence "No config file" warnings for kiro_* modules

### What Changed

Added `noconfig: true` to the `module.desc` of all four custom Python modules: `kiro_before`, `kiro_final`, `kiro_remove_nvidia`, `kiro_ucode`. Also removed four misplaced dummy `.conf` files that had been dropped inside the module code directories.

### Why

Reading `/var/log/Calamares.log` on a freshly installed Kiro system showed four startup warnings of the form `WARNING: No config file for "kiro_before" found anywhere at ...`. Calamares only searches `/etc/calamares/modules/<module>.conf` and `/usr/share/calamares/modules/<module>.conf` for module configs — it never looks inside the module's own code directory at `/usr/lib/calamares/modules/<module>/`. The dummy `.conf` files placed there were invisible to the search, so the warnings continued to fire.

None of the four kiro modules actually read any module-level config — they only use `libcalamares.globalstorage` and `libcalamares.utils`. Calamares supports an explicit `noconfig: true` flag in `module.desc` ([Descriptor.cpp:96](https://codeberg.org/erikdubois/calamares/src/branch/master/src/libcalamares/modulesystem/Descriptor.cpp#L96) reads it; [ModuleManager.cpp:165](https://codeberg.org/erikdubois/calamares/src/branch/master/src/libcalamaresui/modulesystem/ModuleManager.cpp#L165) short-circuits the search when it is set) designed for exactly this case: a module that needs no configuration. This is the truthful, zero-maintenance fix.

### Technical Details

- `noconfig: true` was appended to each of the four `module.desc` files; the indentation of the line matches the existing keys in each file (the `kiro_ucode` descriptor uses padded alignment, the others do not).
- The four misplaced dummy files (`kiro_before/kiro_before.conf`, etc.) under `usr/lib/calamares/modules/` were deleted.
- If a kiro module ever does grow real config, the fix is to flip the flag back off and ship a real `<module>.conf` under `etc/calamares/modules/`.

### Files Modified

- `usr/lib/calamares/modules/kiro_before/module.desc`
- `usr/lib/calamares/modules/kiro_final/module.desc`
- `usr/lib/calamares/modules/kiro_remove_nvidia/module.desc`
- `usr/lib/calamares/modules/kiro_ucode/module.desc`
- Deleted: `usr/lib/calamares/modules/kiro_before/kiro_before.conf`
- Deleted: `usr/lib/calamares/modules/kiro_final/kiro_final.conf`
- Deleted: `usr/lib/calamares/modules/kiro_remove_nvidia/kiro_remove_nvidia.conf`
- Deleted: `usr/lib/calamares/modules/kiro_ucode/kiro_ucode.conf`

---

## 2026-05-19 — Liquorix Kernel Promoted to Production

### Kernel Switch: linux → linux-lqx

The Liquorix kernel (`linux-lqx`) has been validated in `kiro-calamares-config-next` and is now the default kernel for production Kiro installs.

**`unpackfs2.conf`** — source path updated from `vmlinuz-linux` to `vmlinuz-linux-lqx`, and destination from `/boot/vmlinuz-linux` to `/boot/vmlinuz-linux-lqx`. This is the step that copies the kernel into the installed target.

**`kiro_before/main.py`** — preset rename now targets `linux-lqx.preset` instead of `linux.preset`. The installed mkinitcpio preset must match the kernel package name.

**`kiro_final/main.py`** — two changes:

- Added `etc/mkinitcpio.d/linux.preset` to the live-only artifact cleanup list. The archiso live environment ships a `linux.preset`; with `linux-lqx` as the installed kernel, the correct preset (`linux-lqx.preset`) comes from the kernel package and `linux.preset` is a stale artifact that should not persist into the installed system.
- Self-removal step confirmed to remove `kiro-calamares-config` (the production package name).

**`kiro_ucode/main.py`** — gained a `remove_ucode_package()` method that cleans up the non-matching microcode package after installing the correct one. For example, on an Intel machine it installs `intel-ucode` and removes `amd-ucode`, and vice versa. Previously only the correct package was installed; the wrong one could linger.

**`displaymanager.conf`** — trailing newline normalised (cosmetic only).

---

## 2026-04-26
- **`amd-ucode`** package updated → `20260410-1`

---

## 2026-04-15 — Major Module Rewrite Day

### Python Modules
- **`kiro_before/main.py`** — 40+22+8 lines added across 3 commits; expanded pre-install setup logic
- **`kiro_final/main.py`** — 335+171 lines changed across 2 commits; major post-install logic rewrite
- **`kiro_remove_nvidia/main.py`** — 19+11 lines changed; improved Nvidia removal logic
- **`kiro_ucode/main.py`** — 48 lines added (expanded microcode detection), then 6 lines fixed

### Installer Flow
- **Removed `kiro-postinstall`** script (141 lines) — logic fully absorbed into `kiro_final`
- **Removed `shellprocess-final.conf`** + its `settings.conf` entries — now handled natively
- **Removed `pacman-init.service`** symlink — no longer needed at install time
- **`__pycache__`** binaries removed from repo

### Bundled Microcode
- **`intel-ucode-20260227-1`** added as bundled `.pkg.tar.zst`
- **`amd-ucode-20260309-1`** updated
- **`unpackfs2.conf`** updated to reference new ucode paths

### `up.sh`
- Rewritten from 5 → 60 lines — now handles full build-and-deploy flow

---

## 2026-04-14 — Slideshow Overhaul

- **Removed** 3 branding slides (`02cal`, `03cal`, `04cal`) — large originals
- **Replaced** `show.qml` with `show-backup.qml` (209-line full QML slideshow with transitions)
- **Compressed** remaining slides (`09cal`, `10cal`, `11cal`, `12cal`)

---

## 2026-04-09
- **`pkgbuild/`** — added bootloader module schema, tests, `test.yaml`
- **`branding.desc`** — updated product info
- **`up.sh`** — updated

---

## 2026-04-05
- **Branding slides** `06cal`, `07cal`, `08cal` — re-compressed (significant size reduction)

---

## 2026-01-31
- **`kiro_remove_nvidia/main.py`** — expanded (+24 lines), improved detection logic
- **`unpackfs1/2.conf`** — reordered unpack sequences
- **`settings.conf`** — module order updated

---

## 2026-01-11
- **`PKGBUILD`** — version bump, dependency update
- **`packages/main.py`** — minor fix

---

## 2025-12-21
- **`kiro_remove_nvidia/main.py`** — single-line fix

---

## 2025-11-29
- **Branding slides** `01–08cal` — rotated/replaced (6 slides swapped)

## 2025-11-28
- **`partition.conf`** — updated partition layout settings

---

## 2025-11-26
- **`pkgbuild/bootloader/main.py`** — added (966 lines) — custom bootloader module

---

## 2025-11-08/09 — Module Cleanup

- **Removed `displaymanager` module** from pkgbuild (1053-line `main.py`, schema, tests — all gone)
- **`displaymanager.conf`** added to `modules/` (now uses upstream module)
- **`unpackfs1.conf`** — removed (simplified to single unpack)
- **`settings.conf`** — updated module pipeline

---

## 2025-10-21
- **`PKGBUILD`** — version bump

## 2025-10-09
- **Branding** `01cal`, `05cal`, `08cal` — compressed
- **`up.sh`** — rewritten with deploy logic

---

## 2025-07-16 — Full Slideshow Added

- **Added 11 branding slides** (`01cal` through `12cal`) — complete installer slideshow
- **`show.qml`** — rewritten (134 lines) — proper QML slideshow with timed transitions

---

## 2025-07-07
- **`bootloader.conf`** — updated bootloader settings
- **`partition.conf`** — 2 settings added

## 2025-07-03
- **`PKGBUILD`** — significant refactor
- **`build-calamares`** — renamed from `.sh`, logic updated
- **`up.sh`** — rewritten (30 lines changed)

## 2025-07-01
- **`settings.conf`** — module pipeline reordered

---

## 2025-06-25 — PKGBUILD & Wrapper Cleanup

- **Removed `cal-kiro-debugging.desktop`** — debug launcher gone
- **Added `calamares-wrapper`** — proper launch wrapper (38 lines)
- **`PKGBUILD`** — refactored (25 lines changed)
- **Renamed** `calamares-3.3.14.r25.g95aa33f/` → `pkgbuild/` (cleaner folder name)
- **Removed `ucode` module** from pkgbuild (59-line `main.py` gone — now `kiro_ucode` handles it)

---

## 2025-06-24 — Custom Modules Born

All four `kiro_*` Python modules added:
- **`kiro_before/main.py`** — 122 lines — pre-install setup
- **`kiro_final/main.py`** — 304 lines — post-install finalization
- **`kiro_remove_nvidia/main.py`** — 74 lines — Nvidia driver removal
- **`kiro_ucode/main.py`** — 57 lines — CPU microcode installation
- **`pacman-init.service`** added (keyring init at install time)
- **`settings.conf`** simplified — removed many upstream modules
- Added helper scripts: `add-kiro-repo`, `dev`, `kiro-postinstall` (141 lines), `qdd-kiro-repo`

---

## 2025-06-20
- **`services-systemd.conf`** module added (57 lines) — systemd service enable/disable list

---

## 2025-05-29 — Alternate Config Cleanup

- **Removed** all "alternate settings" files: `settings-advanced-remove.conf`, `settings-beginner-remove.conf`, `settings-advanced-no-nivida-remove.conf`
- **Removed** offline/online shellprocess-before variants
- **Renamed** partition/packages configs to `-remove` suffix (cleanup pass)

---

## 2025-05-28 — ArcoLinux Removal

- **Removed all `arcolinux-*` binaries** from `usr/local/bin/` (21 scripts, ~1100 lines total):
  - `arcolinux-all-cores`, `arcolinux-before`, `arcolinux-displaymanager-check`
  - `arcolinux-nvidia-settings` (304 lines), `arcolinux-graphical-target` (60 lines)
  - `arcolinux-virtual-machine-check` (191 lines), `arcolinux-set-bootloader` (87 lines)
  - `arconet-remove-xfce`, `arcopro-remove-sddm`, `arcopro-remove-xfce`, etc.
- **Removed** bundled bootloader `.pkg.tar.zst` files
- **`pacman-init.service`** removed from systemd wants
- All files moved under `etc/calamares/` (was at root `calamares/`)

---

## 2025-05-17 — Build System Bootstrap

- **PKGBUILD** — multiple iterations finalizing calamares build config
- **`build-calamares`** — rewritten from scratch (35→13 line simplification)
- **`.gitignore`** — binary artifacts excluded

---

## 2025-04-29
- **`settings.conf`** — expanded with advanced/beginner/LUKS config variants
- **`unpackfs1/2.conf`** — dual-unpack setup

---

## 2025-04-27 — Initial Commit

- **Full Calamares config bootstrapped** (55 files, 2026 insertions)
  - Branding: `kiro/` theme with logo, stylesheet, language files, 9 slide images
  - Modules: all standard Calamares modules configured
  - Settings: beginner + advanced installer flows
  - PKGBUILD for custom Calamares build
