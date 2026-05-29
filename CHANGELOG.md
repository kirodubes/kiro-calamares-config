# CHANGELOG — kiro-calamares-config

> Calamares graphical installer configuration. Custom Python modules: `kiro_before`, `kiro_final`, `kiro_kernel`, `kiro_plymouth`, `kiro_remove_nvidia`, `kiro_ucode`.

---

## 2026-05-29 — Dark installer: KiroDark Kvantum theme (mirrored from beta)

**What Changed**

Promoted the dark Calamares installer from `kiro-calamares-config-next` to production after a confirmed full install + reboot. The installer now renders dark (navy `#0F172A`, sky-blue `#0EA5E9` accent) matching the website, instead of the old light-grey default. The grey was caused by `-style breeze` falling back to the light default (breeze was never installed); the fix is a custom **KiroDark** Kvantum theme launched via `-style kvantum`.

**Technical Details**

- **branding.desc** — dark sidebar (`#0F172A`/`#E2E8F0`), `SidebarTextHighlight #0EA5E9` + `SidebarSelect #FFFFFF`, `productIcon` + `productWelcome` → `welcome.png` (dark-navy K).
- **stylesheet.qss** — accent `#58B2D7` → `#0284C7`, nav-button `:hover` text → white, selections → white on `#0284C7`, dark scrollbar track.
- **show.qml** — the dark text slideshow (brand slides + slate gradient backdrop that blends with KiroDark).
- **welcome.png** — new dark-navy K (blends into the panel, no white box).
- **kiro_final** — now removes `root/.config/Kvantum` from the target (KiroDark styles the installer-as-root but is live-only cruft on the installed system; verified gone post-install).
- Paired: `kiro-iso` ships the KiroDark theme + `kvantum`; the production `calamares` package launcher drops `calamares-wrapper` and uses `-style kvantum`.

**Files Modified**
- `etc/calamares/branding/kiro/branding.desc`
- `etc/calamares/branding/kiro/stylesheet.qss`
- `etc/calamares/branding/kiro/show.qml`
- `etc/calamares/branding/kiro/welcome.png` (new)
- `usr/lib/calamares/modules/kiro_final/main.py`

---

## 2026-05-29 — `kiro_plymouth` module: Kiro boot splash built into every kernel's initramfs

**What Changed**

New Calamares job module `kiro_plymouth` adds the `plymouth` hook to the target's `/etc/mkinitcpio.conf`, so the Kiro boot splash (`plymouth-theme-kiro-logo`, shipped on the ISO) is built into the initramfs of **every** kernel the user selected — automatically, with no per-kernel work. It runs between `initcpiocfg` (which writes the HOOKS line) and `initcpio` (which runs `mkinitcpio -P` for all presets), inserting `plymouth` right after `udev` and leaving every other hook `initcpiocfg` decided untouched.

Rationale: `initcpiocfg` recomputes HOOKS from the partition layout and never adds plymouth, so the hook had to be injected after it but before the single `mkinitcpio -P`. The splash is kernel-agnostic — that one rebuild embeds it into each preset, and any kernel installed later picks it up via pacman's own `mkinitcpio` run against the same conf. The `splash` cmdline param is already auto-appended by the `bootloader` module when plymouth is present, and the default theme is set at ISO-build time by the package's `.install`, so this module is the only missing piece.

**Technical Details**

- [usr/lib/calamares/modules/kiro_plymouth/main.py](usr/lib/calamares/modules/kiro_plymouth/main.py) — `add_hook()` inserts `plymouth` after `udev` via a `\budev\b` word-anchored regex (count=1), idempotent (no-op if `plymouth` already in HOOKS). Guarded by `plymouth_installed()` (checks `usr/bin/plymouth` in the target) so it never adds a hook that `mkinitcpio` can't satisfy. `module.desc` mirrors `kiro_kernel` (python job, `noconfig: true`).
- [etc/calamares/settings.conf](etc/calamares/settings.conf) — `kiro_plymouth` added to the `exec` sequence between `initcpiocfg` and `initcpio`.
- Mirrored verbatim into the `kiro-calamares-config-next` tree (module + sequence) per the lockstep convention.

**Files Modified**
- `usr/lib/calamares/modules/kiro_plymouth/main.py` (new)
- `usr/lib/calamares/modules/kiro_plymouth/module.desc` (new)
- `etc/calamares/settings.conf`

## 2026-05-29 — `[cachyos]` repo disabled by default on the installed system

**What Changed**

`kiro_final` now comments out the `[cachyos]` repo (header + its `Include` line) in the target `/etc/pacman.conf` at the end of the install. cachyos stays **enabled during** the install — chwd pulls its driver packages from it — and is only disabled afterward, so nothing about driver selection changes. The keyring and mirrorlist remain installed; a user re-enables cachyos by uncommenting the two lines.

Rationale: keeps `pacman -Syu` from silently swapping base packages for cachyos-optimized rebuilds, leaving the installed system closer to stock Arch with cachyos as opt-in. Safe for the **default kernel** because `chaotic-aur` stays enabled and carries `linux-cachyos`/`-headers`, so updates keep flowing. (If `chaotic-aur` is ever dropped, this must be revisited — cachyos would become the sole source for `linux-cachyos`.)

**Technical Details**

- [usr/lib/calamares/modules/kiro_final/main.py](usr/lib/calamares/modules/kiro_final/main.py) — new private `_disable_repo(target_root, repo)` helper comments a repo section (header + body lines until a blank line or next `[section]`); idempotent. Called for `cachyos` from `run()`, after the tuned pin and before bootloader config. Placement is well after chwd in the exec sequence, so drivers install before the repo is disabled.
- chwd skip-marker text ([chwd/main.py](usr/lib/calamares/modules/chwd/main.py)) updated: the retry hint now tells the user to uncomment `[cachyos]` if a driver package can't be found.
- Verified post-install by `kiro-audit`'s `check_pacman_repos` ([edu-system-files](/home/erik/EDU/edu-system-files/CHANGELOG.md)): PASS when cachyos is commented, soft WARN if re-enabled or absent.

**Files Modified**
- `usr/lib/calamares/modules/kiro_final/main.py`
- `usr/lib/calamares/modules/chwd/main.py`

## 2026-05-29 — chwd failure is now non-fatal (install no longer aborts)

**What Changed**

On a laptop install, `chwd --autoconfigure` selected a driver profile whose package set included a package that none of the configured target repos carried. pacman aborted the transaction, the chwd module returned a `(error_title, error_description)` tuple, and Calamares **aborted the whole installation** — leaving the user with no installed system over a missing driver package.

The chwd module now treats a chwd failure as **non-fatal**. When `chwd --autoconfigure` exits non-zero, the module logs a `libcalamares.utils.warning`, writes a breadcrumb to `/var/log/kiro-chwd-skipped.log` on the target, and returns `None` so the install completes on the open driver (nouveau/mesa, already in the ISO). This is safe because pacman transactions are atomic (a missing target installs nothing) and chwd's own `pre_remove` hook removes any mkinitcpio drop-ins it had written, so a failed run leaves no half-configured state.

**Technical Details**

- [usr/lib/calamares/modules/chwd/main.py](usr/lib/calamares/modules/chwd/main.py) — `run()` no longer returns the error tuple from `run_in_host`; on failure it warns, calls the new private `_record_skip(root_mount_point, detail)` helper, sets progress to 1.0, and returns `None`.
- `_record_skip` writes `/var/log/kiro-chwd-skipped.log` (reason + retry hint) into the chroot; an `OSError` while writing is itself non-fatal (warn only).
- Considered a true pre-flight `pacman -Sp` dry-run (the original ask) but chose best-effort: identical end state (drivers if available, else open driver + install intact), ~5 lines, and zero coupling to chwd internals so it survives chwd upstream changes.
- The skip is **not silent**: `kiro-audit`'s new `check_chwd` ([edu-system-files](/home/erik/EDU/edu-system-files/CHANGELOG.md)) surfaces the marker as a WARN on the installed system.

**Files Modified**
- `usr/lib/calamares/modules/chwd/main.py`

## 2026-05-28 — Hardware-aware install via **chwd** (synced from `kiro-calamares-config-next`)

The chwd Calamares module developed and validated in [kiro-calamares-config-next](../kiro-calamares-config-next/) on this same date is now mirrored here. Validated end-to-end on a VirtualBox install: module loaded correctly, read `driver=nonfree` from `/proc/cmdline`, invoked `arch-chroot $rootMountPoint chwd --autoconfigure` inside the target chroot, returned cleanly. All 42 Calamares jobs completed; install booted successfully. The companion package [chwd in nemesis_repo](../../EDU-PKG-BUILD/edu-pkgbuild-3party/chwd/) ships a patched profiles.toml fixing the upstream CachyOS `[virtualbox]` / `[vmware]` vendor_id swap, so VirtualBox guests now match the correct profile and install `virtualbox-guest-utils` via chwd's `--autoconfigure` path.

### Changes synced

**New module: `usr/lib/calamares/modules/chwd/`**

Two-file Python jobmodule modelled after CachyOS's own `cachyos-calamares/src/modules/chwd/`. `module.desc` declares a Python `job` module pointing at `main.py`. `main.py` runs `arch-chroot $rootMountPoint chwd --autoconfigure` inside the target chroot — chwd then inspects PCI/USB devices, matches them against priority-ranked TOML profiles in `/var/lib/chwd/db/`, and installs the right driver bundle (NVIDIA 470xx / 580xx / nvidia-open-dkms / nouveau / AMD / Intel / Broadcom / hybrid PRIME variants for laptops via DMI chassis types 8/9/10/11). The module honours the existing GRUB-menu `driver=` kernel cmdline: on `driver=free` it skips itself entirely so `kiro_remove_nvidia` keeps owning that path; on `driver=nonfree` chwd does the smart hardware-detection install.

**Settings.conf — chwd added to exec sequence**

[etc/calamares/settings.conf](etc/calamares/settings.conf) — `chwd` inserted between `kiro_remove_nvidia` and `initcpiocfg`. Position matters: DKMS modules that chwd installs need to be present before `initcpiocfg` writes the mkinitcpio preset and `initcpio` regenerates the initramfs.

### Why keep `kiro_remove_nvidia`

The two modules are complementary, not overlapping: `kiro_remove_nvidia` is the fast path for `driver=free` (removes baked-in `nvidia-open-dkms` for a pure nouveau install); chwd is the smart path for `driver=nonfree` (looks at the actual GPU and picks the right proprietary variant). Folding them into one is a future cleanup once chwd is fully trusted across hardware variants.

### Pairs With

- [kiro-iso](../kiro-iso/) — needs the same package-list updates as `kiro-iso-next` got: add `chwd`, `b43-fwcutter`, `broadcom-wl-dkms`, `hwdetect` to `archiso/packages.x86_64`. Without these the live ISO has no chwd to run.
- [edu-pkgbuild-3party/chwd](../../EDU-PKG-BUILD/edu-pkgbuild-3party/chwd/) — the patched chwd PKGBUILD in nemesis_repo. Self-validating sed in `prepare()` fixes upstream's swapped vendor_ids for the `[virtualbox]` and `[vmware]` graphic_drivers profiles.

**Files modified**
- `usr/lib/calamares/modules/chwd/module.desc` (new)
- `usr/lib/calamares/modules/chwd/main.py` (new)
- `etc/calamares/settings.conf` — `chwd` inserted between `kiro_remove_nvidia` and `initcpiocfg`

---

## 2026-05-28 — kiro_final pins tuned ppd_base_profile = performance

**Symptom:** Both bare-metal pre-release installs (Picard + Riker, v26.05.28) reported `tuned-adm active = balanced` instead of `throughput-performance`. `/etc/tuned/ppd_base_profile` contained `balanced` and was owned by `tuned 2.27.0-1` per `pacman -Qo`.

**Root cause:** The earlier "fix" assumed `/etc/tuned/ppd_base_profile` was "intentionally absent" so that ppd.conf's `default=performance` fallback would win. That assumption was wrong — the upstream `tuned` package's pacman install writes the file fresh during Calamares' package phase, with content `balanced`. The fall-through to `default=performance` therefore never fires.

**Fix:** New step in `kiro_final/main.py` (between "Configure Bluetooth and PulseAudio" and "Configure bootloader" — last module, so it runs after every package install and overlay write): open `<target>/etc/tuned/ppd_base_profile` and write `performance\n`. Logged as `Pin tuned ppd_base_profile: SUCCESS` in the module result summary. Tradeoff: unconditional overwrite — a user who has manually changed the file and then reinstalls will lose their setting, which is the correct behavior on a fresh install.

Paired with a new `check_tuned_profile` in [edu-system-files/usr/local/bin/kiro-audit](/home/erik/EDU/edu-system-files/usr/local/bin/kiro-audit) that asserts the pinned value + `tuned-adm active == throughput-performance` post-install, so the regression is caught by audit on every future install instead of via syscheck spelunk.

**Files Modified**
- `usr/lib/calamares/modules/kiro_final/main.py`

---

## 2026-05-28 — multi-kernel install: cmdline-duplication fix + mkinitcpio churn cut

Two install-time fixes surfaced by the first multi-kernel install (cachyos + zen, see [kiro-iso/DISTRO_TESTING.md](/home/erik/KIRO/kiro-iso/DISTRO_TESTING.md)).

### Bug fix — duplicated `rw root=UUID=…` in second kernel's boot-loader entry

**Symptom:** On a 2-kernel install, the first kernel's `/boot/efi/loader/entries/*.conf` had a clean `options` line; the second kernel's entry had `rw root=UUID=…` appearing **twice**. Root cause traced to `/etc/kernel/cmdline` itself being written with the duplicates — so any subsequent kernel install (`pacman -U linux-foo`) on the user's system would also inherit them.

**Root cause:** [bootloader/main.py:133-148](etc/calamares/pkgbuild/modules/bootloader/main.py) — `get_kernel_params(uuid)` did:

```python
kernel_params = libcalamares.job.configuration.get("kernelParams", ["quiet"])
```

`libcalamares.job.configuration.get()` returns a **reference** to the config-stored list, not a copy. Every subsequent `.append("rw")` / `.append("root=UUID=…")` / `.extend(…)` mutated that shared, config-backed list. When `get_kernel_params()` is called more than once per install — which happens because `create_systemd_boot_conf()` is invoked once per installed kernel — the second call starts from the already-mutated list and re-appends, producing the duplicates.

`quiet nowatchdog` come from config and never duplicate (they're already in the list before any `.append`); only the runtime-appended `rw` + `root=UUID=` show the doubling. That signature confirmed the diagnosis precisely.

**Fix:** defensive copy via `list(…)` wrapper. One line:

```python
kernel_params = list(libcalamares.job.configuration.get("kernelParams", ["quiet"]))
```

Now every call starts from a fresh local list; the config-stored value is never mutated. Long comment block left in the code explaining why — the bug is the kind that takes hours to re-diagnose if it ever regresses.

### Performance — collapsed mkinitcpio passes from 5 → 1 during install

**Observation:** A 2-kernel install ran `==> Building image from preset` **5 times** (10 image builds total) during a ~4-minute Calamares run — `~30-60s of pure churn`. Root cause: every package operation in the install pipeline triggers the upstream `/usr/share/libalpm/hooks/90-mkinitcpio-install.hook`, which rebuilds initramfs for every installed kernel. Triggering events seen 2026-05-28:

1. `nvidia-*` DKMS removal in `kiro_remove_nvidia` (modules dir change)
2. The official Calamares `initcpiocfg` + `Creating initramfs with mkinitcpio…` job (job 23-24 of 41)
3. `pacman -Rs --noconfirm mkinitcpio-archiso` in the packages module (initcpio files dir change)
4. Microcode reinstall in `kiro_ucode`
5. Second pass after another microcode-related action

Only **#2** is needed — it's the explicit Calamares job that invokes `mkinitcpio -P` directly (not via the hook) with the final `/etc/mkinitcpio.conf`. The other four are hook-triggered duplicates of the same work.

**Fix:** standard `etc/pacman.d/hooks/<hookname>` override pattern:

- **`kiro_before`** (job 21/41, early): new `suppress_mkinitcpio_hook()` step that symlinks `<target>/etc/pacman.d/hooks/90-mkinitcpio-install.hook` → `/dev/null`. Pacman's hook-resolver prefers `/etc/pacman.d/hooks/` over `/usr/share/libalpm/hooks/`, so a `/dev/null` override silently nullifies the upstream hook. Best-effort: a failure here only loses the optimisation, doesn't break the install.

- **`kiro_final`** (job 39/41, end): new restore block at the very end of `run()`, after every package operation in this module. Removes the symlink so the user's first `pacman -Syu` rebuilds initramfs normally on kernel upgrades. **MUST run** — a stuck `/dev/null` symlink would leave the user's system unable to refresh initramfs after any future kernel package change. Wrapped in its own try/except so an earlier kiro_final failure can't skip it.

The explicit Calamares mkinitcpio job at step 23-24 still runs because it invokes mkinitcpio directly, not via the pacman hook — so the source-of-truth initramfs pass is preserved. Estimated save: ~30-60s on a 2-kernel install (5 hook-triggered passes × 2 kernels = 10 image builds → 1 pass × 2 kernels = 2 image builds).

### Performance — extended hook suppression to 6 more cache-rebuild hooks

Same pattern as the mkinitcpio fix above, generalised to the other heavyweight cache-rebuild pacman hooks that fire per transaction during install. With 4+ pacman transactions in the pipeline (`kiro_remove_nvidia`, `packages`, `kiro_ucode`, `kiro_final` removals) each one re-runs the same expensive chain from scratch.

Hooks now shadowed to `/dev/null` in the chroot (in addition to `90-mkinitcpio-install.hook`):

- `gtk-update-icon-cache.hook` — icon theme caches
- `update-desktop-database.hook` — `.desktop` MIME cache
- `30-update-mime-database.hook` — shared MIME database
- `fontconfig.hook` — `fc-cache`
- `dconf-update.hook` — system dconf databases
- `xorg-mkfontscale.hook` — X font dir indices

**`kiro_before/main.py`** — `suppress_mkinitcpio_hook()` renamed to `suppress_pacman_hooks()` and now iterates a module-level `SUPPRESSED_HOOKS` tuple. Same `/dev/null` shadow-symlink trick under `/etc/pacman.d/hooks/`.

**`kiro_final/main.py`** — old single-hook restore replaced with two helpers: `restore_suppressed_hooks()` (loops over the same tuple, unlinks each shadow symlink) and `rebuild_caches_once()` (runs each hook's underlying command exactly ONCE in the chroot via a `CACHE_REBUILD_STEPS` table). Without the one-shot rebuild the installed system would boot with stale caches (missing icons, unknown MIME types, blank font lists, no dconf defaults). The mkinitcpio hook has no entry in the rebuild table — Calamares' explicit `initcpio` job already rebuilt initramfs before kiro_final runs.

Realistic save: 15-30s on top of the existing mkinitcpio fix. VM-install benchmark vs the post-mkinitcpio-fix baseline still pending.

### Performance — guard `kiro_ucode.remove_ucode_package()` with a pre-existence check

[kiro_ucode/main.py](usr/lib/calamares/modules/kiro_ucode/main.py): the "wrong microcode" removal previously called `pacman -R --noconfirm <pkg>` unconditionally and caught the failure when the package wasn't there. Added a `pacman -Q` guard via a new `is_installed_in_target()` method mirroring the `kiro_remove_nvidia._is_installed_in_target()` pattern. When the wrong-vendor microcode isn't installed (the normal case — the live ISO ships microcode as bundled `.pkg.tar.zst` rather than as installed packages) we now skip the `pacman -R` call entirely.

Save: small (~2-3s per install), but free. Counterpart fix for `kiro_remove_nvidia` was unnecessary — that module already had `_is_installed_in_target()` guarding the candidate list.

### Performance — mtime-gated cache rebuilds + VM-skip for kiro_ucode

Follow-up to the earlier "extended hook suppression" change. The first measurement showed install was actually ~6 s **slower** with all 6 cache rebuilds running unconditionally in `kiro_final` (`update-mime-database` alone cost ~8 s, fc-cache ~2 s, while the corresponding hooks would only have fired for transactions that touch their trigger paths — which the Kiro install pipeline mostly doesn't). Two changes to recover that time without giving up the first-boot freshness guarantee:

**`kiro_before/main.py`** — new `snapshot_cache_trigger_mtimes()` step that records the pristine mtime of every cache trigger dir (`usr/share/icons`, `usr/share/applications`, `usr/share/mime/packages`, `usr/share/fonts`, `etc/dconf/db`) into `libcalamares.globalstorage` under key `kiroCacheMtimeBaseline`. Runs after the lock wait and before any pacman op, so we capture the post-unpackfs state.

**`kiro_final/main.py`** — `CACHE_REBUILD_STEPS` now carries the trigger dir alongside the description and command. New `_cache_trigger_changed()` helper compares current mtime against the baseline; `rebuild_caches_once()` skips any step whose trigger dir mtime is unchanged. Defensive default: when the baseline is missing or the dir can't be stat'd, we rebuild (favour correctness over speed). Limit: only the top-level dir's own mtime is checked, not files inside its subdirs — that matches pacman's hook trigger semantics without an expensive recursive walk.

**`kiro_ucode/main.py`** — added `_detect_target_virt()` and an early-return at the top of `run()` when `systemd-detect-virt` in the target chroot reports anything other than `none`. The hypervisor handles guest microcode, so the `pacman -U <vendor>-ucode` + `pacman -R <other-vendor>-ucode` work is pure waste on a VM (~5 s per install). Bare metal is untouched. Both ucode packages stay installed in their live-ISO state; the kernel ignores them on a guest CPU. Counterpart of `kiro_final`'s existing `VM_CLEANUP_BY_TYPE` logic.

Expected combined save vs the previous build: ~10-12 s on VM installs (skip kiro_ucode + skip mime/font/dconf/mkfontscale rebuilds when triggers untouched); ~5-10 s on bare metal.

### Ruff cleanups (incidental, in the same file)

[bootloader/main.py](etc/calamares/pkgbuild/modules/bootloader/main.py): four pre-existing lint hits in upstream-derived code, fixed while in the file:

- L659: `not (x in y)` → `x not in y` (E713)
- L858 (refind branch): removed unused `install_efi_directory = …` assignment (F841)
- L896: stripped unnecessary `f""` prefix (F541)
- L949: `install_hybrid_grub == True` → `install_hybrid_grub` (E712)

### Files modified

- `etc/calamares/pkgbuild/modules/bootloader/main.py` (cmdline defensive copy + 4 ruff fixes)
- `usr/lib/calamares/modules/kiro_before/main.py` (`suppress_mkinitcpio_hook` + register)
- `usr/lib/calamares/modules/kiro_final/main.py` (restore block at end of `run()`)

### Follow-ups

- Mirror to `kiro-calamares-config-next` once verified.
- Verification path: rebuild `kiro-calamares-config-git`, rebuild ISO, re-test VM install, then bare metal — confirm zen entry's cmdline is single-`rw`-single-`root=UUID=` AND grep `==> Building image` in Calamares.log returns 2 lines (one per kernel) instead of 10.

---

## 2026-05-27 — kiro_final: remove the live-only desktop-launcher trust helper

`kiro_final` now removes **`/usr/local/bin/kiro-trust-desktop-launchers`** from the installed system. That helper is a new live-ISO autostart (added in `kiro-iso`) that pre-trusts the **Install kiro** desktop launcher so XFCE/Thunar doesn't prompt — useful only on the live session, so it's added to the `paths_to_remove` list. Its autostart entry under `/home/liveuser/.config/autostart/` needs no explicit cleanup: `removeuser` deletes the live user's home earlier in the sequence, so listing it could even error depending on timing.

## 2026-05-27 — kernel-agnostic installer (new `kiro_kernel` module)

### What Changed

- **New `kiro_kernel` module makes the installer independent of the ISO's kernel package.** Previously three places hardcoded `linux-lqx`: the `unpackfs@vmlinuz` job (copied `vmlinuz-linux-lqx` from the live medium), `kiro_before`'s preset rename (`kiro` → `linux-lqx.preset`), and the static `kiro` preset. `kiro_kernel` now **loops over every** `vmlinuz-*` on the live medium (`/run/archiso/bootmnt/arch/boot/x86_64/`), copying each image to `/boot/vmlinuz-<kernel>`, generating a matching `/etc/mkinitcpio.d/<kernel>.preset`, and removing the live-only preset artifacts (`kiro`, `linux.preset`) **first** so the plain `linux` kernel's preset isn't clobbered. So an ISO built with any kernel — or several — installs correctly with **zero edits to the calamares config**.
- **`unpackfs@vmlinuz` removed**, replaced by `kiro_kernel` in the exec sequence (same slot, after `unpackfs@rootfs`); the `vmlinuz` unpackfs instance and `unpackfs2.conf` deleted.
- **`kiro_before` no longer renames the preset** — `move_mkinitcpio_preset()` and its step removed; preset handling lives entirely in `kiro_kernel`. Stores `kiroKernels` (list) + `kiroKernel` (primary) in globalstorage.

### Technical Details

- Developed and validated on `kiro-calamares-config-next` first, then mirrored here byte-for-byte (the kernel-touched files diff identical to the proven `-next` versions). **Proven end-to-end on real installs:** CachyOS (single kernel) and `linux-lts` + `linux-zen` (multi-kernel) both installed and booted, with all kernels' images, initramfs, and intact headers present. Paired with `kiro-iso`'s build-side kernel selector.
- `initcpio.conf` runs `mkinitcpio -P` (all presets), so each generated `<kernel>.preset` yields one initramfs; `kiro_final`'s `linux.preset` removal is left as a guarded no-op.

### Files Modified

- [usr/lib/calamares/modules/kiro_kernel/main.py](usr/lib/calamares/modules/kiro_kernel/main.py) (new)
- [usr/lib/calamares/modules/kiro_kernel/module.desc](usr/lib/calamares/modules/kiro_kernel/module.desc) (new)
- [etc/calamares/settings.conf](etc/calamares/settings.conf)
- [usr/lib/calamares/modules/kiro_before/main.py](usr/lib/calamares/modules/kiro_before/main.py)
- [etc/calamares/modules/unpackfs2.conf](etc/calamares/modules/unpackfs2.conf) (deleted)

## 2026-05-26 — cups printing + logrotate.timer enabled on installed system

### What Changed

- **`services-systemd` now enables `cups.socket`.** Printing was off after a fresh install + reboot. The live ISO enabled CUPS via airootfs symlinks, but those are not carried into the installed system, and the Calamares `services-systemd` unit list (ananicy-cpp, tuned, tuned-ppd, firewalld) never enabled cups. Added a `cups.socket` → `enable` → `mandatory: true` entry. Socket activation only — `cups.service` starts on demand when a client opens the print socket, so there is no always-running daemon. Paired with `kiro-iso`, which trims its airootfs cups symlinks to socket-only.
- **`services-systemd` now enables `logrotate.timer`.** On a fresh install the timer was active-but-not-enabled (`is-enabled` = disabled), so its persistence wasn't guaranteed. Enabling it explicitly caps unbounded growth of file-based logs (`pacman.log`, Xorg/app logs); journald rotates its own store separately via `SystemMaxUse`. Set `mandatory: false` so a log-rotation timer can never abort an install. `man-db.timer` was reviewed alongside and **declined** (only refreshes the apropos index; periodic SSD/laptop wakeup churn for marginal benefit). Mirrored to `kiro-calamares-config-next`.

### Files Modified

- [etc/calamares/modules/services-systemd.conf](etc/calamares/modules/services-systemd.conf)

## 2026-05-26 — README: community framing, dropped "personal"

### What Changed

- **README no longer calls Kiro "my personal choice".** The defaults list (systemboot, ext4, sddm, xfce4 and chadwm, free software) is now introduced as "Kiro ships with opinionated defaults so it works out of the box" — community framing instead of the early single-user wording. Rule codified in [Kiro-HQ/ASSISTANT.md](../../Insync/Kiro/Kiro-HQ/ASSISTANT.md). README only; no installer behaviour changed, no rebuild needed.

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
