# CHANGELOG — kiro-calamares-config

> Calamares graphical installer configuration. Custom Python modules: `kiro_before`, `kiro_final`, `kiro_remove_nvidia`, `kiro_ucode`.

---

## 2026-05-25 — kiro_final: remove live-only do-not-suspend.conf

### What Changed

- **`kiro_final` now removes `/etc/systemd/logind.conf.d/do-not-suspend.conf` on the installed system.** This drop-in (`HandleSuspendKey` / `HandleHibernateKey` / `HandleLidSwitch=ignore`) ships in the airootfs overlay so the live ISO does not suspend mid-install, but it was never cleaned up afterward — it persisted on every installed system and silently disabled suspend / hibernate / lid handling for end users (notably on laptops). Added it to the `paths_to_remove` list alongside the other live-only artifacts.

### Technical Details

- One-line addition to `paths_to_remove` in `kiro_final/main.py`, grouped with the existing live-only cleanups (getty autologin, `linux.preset`, `10-archiso.conf`); reuses the existing `remove_path()` helper, so no change to the removal loop.
- Caught by `kiro-check` on an installed Kiro system. `kiro-audit` has no check for this file, so the leak had been passing the audit clean.

### Files Modified

- `usr/lib/calamares/modules/kiro_final/main.py`
- `CHANGELOG.md`

## 2026-05-24 — PKGBUILD Promotion, Swap Options, Repo Sync

### What Changed

- **PKGBUILD identity flipped to canonical** — the package now `provides=('calamares')` and `conflicts=('calamares-next' 'calamares-git')`, the reverse of the previous `provides=('calamares-next')` / `conflicts=('calamares' 'calamares-git')`. This config repo's build is now the production `calamares` package, with the `-next` repo holding the beta. `pkgver` placeholder bumped `3.3.14.r132` → `3.4.2.r4`, `pkgrel` `3` → `1`, and the `calamares-wrapper` sha256 refreshed.
- **partition.conf swap choices expanded** — re-enabled the previously commented-out `small` (up to 4GB) and `suspend` (≥ RAM size) options. `userSwapChoices` now offers `none / small / suspend / file`; `suspend` enables hibernation.
- **cal-kiro.desktop rebranded** — `Name`/`Comment` changed from "Install ArcoLinux" / "Installer for ArcoLinux" to "Install kiro" / "Installer for kiro". The live-desktop copy is now installed executable (`-Dm755` + explicit `chmod +x`) so it launches without the "untrusted desktop file" prompt.
- **amd-ucode bundle updated** `20260410-1` → `20260519-1` (`.pkg.tar.zst` + `.sig` swapped).
- **`calamares-widget-tree` branding file removed** (572 lines) — stale/unused.

### Technical Details

- **`up.sh` gained two sync functions.** `update_ucode()` refreshes the bundled microcode packages; `update_pkgbuild()` copies the latest hand-built PKGBUILD folder from `~/KIRO-PKG-BUILD` into `etc/calamares/pkgbuild/`. The sync only considers `calamares-3*` folders (skipping the `calamares-next-*` beta folders that belong to the `-next` config repo), picks the highest version via `sort -V`, and **strips** `up.sh`, `setup.sh`, `.current-version`, `.previous-version` from the destination after the copy — those belong to `KIRO-PKG-BUILD`, not this repo. Stripping is unconditional so it also clears remnants from earlier syncs.
- A `build.sh` helper was added under `etc/calamares/pkgbuild/`. **Remember:** the PKGBUILD and its build helpers are authored in `~/KIRO/kiro-pkgbuild/` (now synced via `~/KIRO-PKG-BUILD`) — do not hand-edit them here.

### Files Modified

- `etc/calamares/pkgbuild/PKGBUILD`, `etc/calamares/pkgbuild/cal-kiro.desktop`, `etc/calamares/pkgbuild/build.sh` (added)
- `etc/calamares/modules/partition.conf`
- `etc/calamares/packages/amd-ucode-20260519-1-any.pkg.tar.zst` (+ `.sig`); removed `20260410-1`
- Deleted: `etc/calamares/branding/kiro/calamares-widget-tree`
- `up.sh`

---

## 2026-05-23 — README Polish

- **README.md** — logo switched to centered HTML (`<p align="center"><img src="kiro.jpg" width="220">`) instead of a full-width markdown image.
- **kiro.jpg** recompressed 196 KB → 37 KB.

---

## 2026-05-22 — VM Cleanup Correctness, tuned, pacman -Sy, gpt default

### Bare-metal VM cleanup was silently skipped (kiro_final)

`systemd-detect-virt` **exits 1 on bare metal** while still printing `none` to stdout. The previous `subprocess.run(check=True)` raised `CalledProcessError`, the handler returned `"unknown"`, and all three VM-cleanup branches were skipped — so `open-vm-tools`, `qemu-guest-agent`, and `virtualbox-guest-utils` (plus their orphan service symlinks) shipped through to installed bare-metal systems.

- Dropped `check=True` so stdout is captured regardless of exit code; empty output falls back to `"unknown"`.
- Refactored the three nested `if vm_type in [...]` blocks into a declarative `VM_CLEANUP_PROFILES` + `VM_CLEANUP_BY_TYPE` table dispatched through a single `cleanup_vm_profile()` helper. Behaviour preserved for all existing `vm_type` values; `none` (bare metal) strips all three profiles.
- Orphan `multi-user.target.wants/` symlinks (`vmtoolsd`, `vmware-vmblock-fuse`, `qemu-guest-agent`, `vboxservice`) are now unlinked **unconditionally** per profile — `pacman -Rns` removes the unit file but not the enable-time symlink, and `systemctl disable` inside the chroot is unreliable without a running dbus.

### tuned enabled on install (services-systemd.conf)

Added `tuned.service` and `tuned-ppd.service` (both `mandatory: true`) to `services-systemd`. The kiro-iso airootfs enables them and pins `throughput-performance`, but Calamares does not preserve the airootfs `.wants/` symlinks across install — packages landed but services came up disabled, so installed systems fell back to tuned's `balanced` default. `/etc/tuned/active_profile` already copies through `unpackfs`, so enabling the service restores the intended profile.

### pacman sync DBs refreshed (kiro_before)

Added a `sync_pacman_databases()` step (after key init, before any later pacman use) running `pacman -Sy --noconfirm` in the chroot. Without it the ISO's bundled `/var/lib/pacman/sync/` is empty/stale, and `kiro_remove_nvidia` / `kiro_ucode` / `kiro_final` emitted ~20 `database file for 'core' does not exist (use '-Sy')` warnings. Best-effort: a flaky mirror is logged and swallowed. Gated on Calamares' `hasInternet` globalstorage flag — explicit `False` skips cleanly instead of waiting on a pacman timeout; unset/unknown still attempts.

### gpt as default partition table (partition.conf)

Set `defaultPartitionTableType: gpt` to silence the install-time "setting is unset, will use gpt/msdos" warning. Matches Kiro's EFI-first stance; BIOS installs still get the correct table per medium.

### Silenced "No config file" warnings (kiro_* module.desc)

Added `noconfig: true` to all four custom modules' `module.desc` and removed four misplaced dummy `.conf` files that had been dropped inside the module code directories. Calamares only searches `/etc/calamares/modules/` and `/usr/share/calamares/modules/` for configs — never the module's own code dir — so those dummies were invisible and the warnings kept firing. None of the four modules read module-level config (they use only `globalstorage` + `utils`), and Calamares supports `noconfig: true` ([Descriptor.cpp:96](https://codeberg.org/erikdubois/calamares/src/branch/master/src/libcalamares/modulesystem/Descriptor.cpp#L96) / [ModuleManager.cpp:165](https://codeberg.org/erikdubois/calamares/src/branch/master/src/libcalamaresui/modulesystem/ModuleManager.cpp#L165)) for exactly this case. If a module ever grows real config, flip the flag off and ship a real `<module>.conf` under `etc/calamares/modules/`.

### Files Modified

- `usr/lib/calamares/modules/kiro_final/main.py`
- `usr/lib/calamares/modules/kiro_before/main.py`
- `etc/calamares/modules/services-systemd.conf`
- `etc/calamares/modules/partition.conf`
- `usr/lib/calamares/modules/{kiro_before,kiro_final,kiro_remove_nvidia,kiro_ucode}/module.desc`
- Deleted: the four misplaced `usr/lib/calamares/modules/<module>/<module>.conf` dummies

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
