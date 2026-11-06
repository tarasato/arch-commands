# Installing software on Arch Linux without the AUR

> A guide for power users · information checked 2026-11-06 · in English
> Translated from the Thai original `arch-linux/install-without-aur.md` on 2026-11-06.
> Every example in this guide is **illustrative and has not actually been run/tested**. File names/internal layout of vendor archives may differ from what is written here — always inspect with `bsdtar -tf` first.

Confidence labels:
- ✅ Confirmed (primary source, e.g. archlinux.org/packages, man pages, upstream docs)
- ⚠️ Evidence exists but is not solid (single source / search snippet only / outdated information)
- 🗣️ Still disputed
- ❓ Not yet confirmed

> **Important note on sources:** at the time of checking (2026-11-06), wiki.archlinux.org, gitlab.archlinux.org and aur.archlinux.org returned the Anubis bot-protection "Access Denied" page for every page. ArchWiki information in this guide was therefore **seen via search snippets only** (labeled as such). Package names/repos/versions were checked directly on archlinux.org/packages, and tool behavior was checked on man.archlinux.org.

---

## Contents

0. [Summary](#0-summary)
1. [Decision tree](#1-decision-tree)
2. [Required tools + which repo each is in](#2-required-tools--which-repo-each-is-in)
3. [.tar.gz / .tar.xz / .tar.zst](#3-targz--tarxz--tarzst)
   - 3A [Prebuilt binaries](#3a-prebuilt-binaries)
   - 3B [Source code](#3b-source-code)
4. [.deb on Arch](#4-deb-on-arch)
5. [.rpm on Arch](#5-rpm-on-arch)
6. [The most "Arch-correct" way: write your own PKGBUILD](#6-the-most-arch-correct-way-write-your-own-pkgbuild)
   - **6.0 [Step by step: first PKGBUILD → `makepkg -si` → install / verify / update / remove with pacman](#60-step-by-step-first-pkgbuild--makepkg--si--install--verify--update--remove-with-pacman)** ← start here
   - 6a packaging a binary tarball · 6b packaging a .deb · 6c building from source
7. [distrobox / podman](#7-distrobox--podman)
8. [Flatpak / AppImage](#8-flatpak--appimage)
9. [Other channels: pipx, cargo, npm, go, Homebrew, Nix](#9-other-channels)
10. [Security](#10-security)
11. [Assumptions](#11-assumptions)
12. [Implications for decisions (recommendations)](#12-implications-for-decisions-recommendations)
13. [Still unanswered + how to find out](#13-still-unanswered--how-to-find-out)
14. [Oddities found](#14-oddities-found)
15. [How to update each method](#15-how-to-update-each-method) — pacman · PKGBUILD · Flatpak · AppImage · manual install · Stow · distrobox · pipx/cargo/npm/go/Nix · combined routine
16. [Cheat sheet](#16-cheat-sheet) (includes an update-method column)
17. [References](#17-references)

---

## 0. Summary

- The best route in almost every case is to let **pacman own the files**: look in the official repos first (`pacman -Ss`, `pacman -F`); if it isn't there, **write your own PKGBUILD and `makepkg -si`**, which works for tarballs, .deb, .rpm and source without relying on the AUR at all
- For a GUI app that is on Flathub, use Flatpak (fastest, updates itself, sandboxed) · AppImage works but needs `fuse2` · if it depends heavily on Debian/Fedora libraries, use distrobox
- Don't `sudo make install` into `/usr`, and don't use `pacman --overwrite` to fix file conflicts · if you must install by hand, put it in `/usr/local`, `/opt` or `~/.local` and keep a record
- All tools used are in the official repos (`base-devel`, `pacman-contrib`, `namcap`, `libarchive`, `rpm-tools`/`rpmextract`, `distrobox`, `podman`, `flatpak`, `fuse2`) **except `debtap` and AppImageLauncher, which are AUR-only**; this guide gives alternatives that don't need either of them

---

## 1. Decision tree

```
You have a file/program name you want to install
│
├─(1) Is it in the official repos?        pacman -Ss <name> ; pacman -F <wanted-file>
│     └─ yes → sudo pacman -Syu <pkg>      ← done (best)
│
├─(2) Is it a GUI app available on Flathub?  flatpak search <name>
│     └─ yes → flatpak install flathub <app-id>
│
├─(3) Does the vendor ship an AppImage?
│     └─ yes → use it directly (needs fuse2) or wrap it in a PKGBUILD if you want pacman to manage it
│
├─(4) Is there a tarball / .deb / .rpm / source?
│     └─ write your own PKGBUILD → makepkg -si    ← the most "Arch" way, remove with pacman -R
│
├─(5) Packaged but won't run (glibc/library mismatch, complex postinst needed, really needs another distro)?
│     └─ distrobox + podman: install the .deb/.rpm in a container, then distrobox-export
│
└─(6) No other option / just a temporary trial
      └─ install by hand into /opt, /usr/local or ~/.local (never /usr) + record the file list for removal
```

**Rationale for this order** (author's analysis, based on pacman behavior confirmed from the man page):

| Item | Rationale |
|---|---|
| official repos first | pacman tracks every file (`pacman -Ql`, `-Qo`), removes everything with `-R`, updates along with the system via `-Syu`, and libraries are already rebuilt to match the system ✅ [pacman(8)](https://man.archlinux.org/man/pacman.8) |
| use `-Syu`, not `-Sy` | ArchWiki states partial upgrades are unsupported and says to avoid `pacman -Sy` followed by `pacman -S pkg` ⚠️ search snippet only [System maintenance](https://wiki.archlinux.org/title/System_maintenance) |
| Flatpak before PKGBUILD (for GUI) | nothing to maintain yourself, update with `flatpak update`, has its own runtime so it isn't affected by Arch library issues (trade-offs: uses disk space, the sandbox may block access to files/devices, many Flathub packages are not made by the vendor) |
| AppImage | single file, doesn't touch the system, but has no central update mechanism and no sandbox |
| your own PKGBUILD | gets all of pacman's benefits (tracking/removal/file-conflict checks) but you must bump versions yourself |
| distrobox | solves library mismatches well, but is not a sandbox and has container overhead |
| manual install last | pacman doesn't know the files → hard to remove, conflicts with future packages (pacman will error with "conflicting files", by design) ⚠️ search snippet only [pacman](https://wiki.archlinux.org/title/Pacman) |

### Commands to check the official repos

```bash
# Update the whole system first (never a bare -Sy)
sudo pacman -Syu

# Search names/descriptions
pacman -Ss obsidian

# Find which package contains a file (e.g. a binary or .so) — the files database must be synced separately first
sudo pacman -Fy
pacman -F libfuse.so.2          # find the package that has this file
pacman -F -x 'bin/rg$'          # regex form
pacman -Fl fuse2                # list files of a package that isn't installed
```

- ✅ `-F` queries only the sync database, `-y` downloads a fresh files database, `-x` uses regex, `-l` lists files — [pacman(8)](https://man.archlinux.org/man/pacman.8) · checked 2026-11-06
- ⚠️ the files database is separate from the regular sync database and must be fetched with `pacman -Fy` · `pacman-contrib` has `pacman-filesdb-refresh.timer` for weekly refresh (seen in a search snippet of the Russian-language ArchWiki) — [pacman](https://wiki.archlinux.org/title/Pacman) · checked 2026-11-06

> **Real example of why you should check first:** Obsidian ships an AppImage/.deb, but `obsidian` 1.15.0-1 is now in **[extra]** ✅ [archlinux.org/packages](https://archlinux.org/packages/?q=obsidian) · checked 2026-11-06 → `sudo pacman -S obsidian` and you're done

---

## 2. Required tools + which repo each is in

Checked on archlinux.org/packages on 2026-11-06 (versions change constantly; ✅ for every row unless noted)

| Tool | Package | Repo | Version seen | Notes |
|---|---|---|---|---|
| `makepkg`, `pacman` | `pacman` (pulled in by `base-devel`) | [core] | — | |
| build toolchain | `base-devel` | [core] | 1-2 | meta package: archlinux-keyring, autoconf, automake, binutils, bison, debugedit, fakeroot, file, findutils, flex, gawk, gcc, gettext, grep, groff, gzip, libtool, m4, make, pacman, patch, pkgconf, sed, sudo, texinfo, which |
| `ar`, `readelf`, `objdump` | `binutils` | [core] | — | already in `base-devel` |
| `bsdtar`, `bsdcpio` | `libarchive` | [core] | — | can read ar (.deb) and the RPM wrapper |
| `gpg` | `gnupg` | [core] | 2.4.9-4 | |
| `updpkgsums`, `checkupdates`, `pactree`, `paccache` | `pacman-contrib` | [extra] | 1.13.1-1 | **not in base-devel** |
| `namcap` | `namcap` | [extra] | 3.6.0-3 | **not in base-devel** |
| `pkgctl`, clean chroot build | `devtools` | [extra] | 1:1.5.3-1 | not needed for personal use |
| `rpm2cpio`, `rpm2archive`, `rpm` | `rpm-tools` | [extra] | 6.0.1-2 | |
| `rpm2cpio`, `rpmextract.sh` | `rpmextract` | [extra] | 1.0-11 | small script, depends on bash, coreutils, libarchive |
| `cpio` | `cpio` | [extra] | 2.15-3 | |
| `stow` | `stow` | [extra] | 2.4.1-1 | GNU Stow |
| `cmake` / `meson` | `cmake` / `meson` | [extra] | 4.4.5-1 / 1.12.1-2 | |
| `git` | `git` | [extra] | 2.56.0-1 | |
| `patchelf` | `patchelf` | [extra] | 0.19.3-1 | edits a binary's RPATH/interpreter |
| `desktop-file-validate` | `desktop-file-utils` | [extra] | 0.28-1 | |
| `distrobox` | `distrobox` | [extra] | 1.8.2.5-1 | GUIs `boxbuddy`, `distroshelf` are also in [extra] |
| `podman` | `podman` | [extra] | 6.1.4-1 | |
| `flatpak` | `flatpak` | [extra] | 1:1.18.4-2 | installs `flathub.flatpakrepo` into `/usr/share/flatpak/remotes.d/` |
| FUSE 2 (for AppImage) | `fuse2` | [extra] | 2.9.9-6 | |
| `pipx` | `python-pipx` | [extra] | 1.18.4-2 | |
| `cargo` | `rust` (provides cargo) or `rustup` | [extra] | 1:1.99.1-1 / 1.29.2-1 | these two conflict with each other |
| `go` | `go` | [extra] | 2:1.27.3-1 | |
| `npm` | `npm` | [extra] | 12.2.2-1 | |
| `nix` | `nix` | [extra] | 2.35.4-1 | |
| **`debtap`** | — | **AUR only** | — | searching the official repos gives 0 results ✅ · that it's in the AUR ⚠️ (couldn't open the AUR page due to Anubis; seen from the upstream README and external articles) |
| **AppImageLauncher** | — | **AUR only** (for Arch) | — | ⚠️ per the upstream README · not found in the official repos ✅ |
| Gear Lever | — | **not in the official repos** · available on Flathub (`it.mijorus.gearlever`) | 4.6.2 (Flathub) | |
| Homebrew | — | not found in the official repos (searched "homebrew") ⚠️ | — | installed via upstream's script |

```bash
# Recommended set to keep installed (all from the official repos)
sudo pacman -Syu --needed base-devel pacman-contrib namcap git
```

---

## 3. .tar.gz / .tar.xz / .tar.zst

Always look inside before extracting, to tell whether it's a binary or source:

```bash
mkdir -p ~/build/inspect && cd ~/build/inspect
bsdtar -tf ~/Downloads/something.tar.gz | head -50
# has configure / CMakeLists.txt / meson.build / Makefile / *.c → source (go to 3B)
# has bin/ + ELF files / .so / launcher script → binary (go to 3A)
```

`bsdtar` (from `libarchive` [core]) and GNU `tar` detect the compression type (.gz/.xz/.zst) automatically ✅ [libarchive README](https://raw.githubusercontent.com/libarchive/libarchive/master/README.md)

### 3A. Prebuilt binaries

> **Real example (not tested):** JetBrains Toolbox App ships as a `.tar.gz` with a `.sha256` file · the latest version per JetBrains' API is 3.9.1.89198 · URL `https://download.jetbrains.com/toolbox/jetbrains-toolbox-3.9.1.89198.tar.gz` ✅ [JetBrains releases API](https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release) · checked 2026-11-06 · not in the official repos ✅ [archlinux.org/packages](https://archlinux.org/packages/?q=jetbrains)
> The tarball's internal layout and Toolbox's self-update behavior **have not been checked** ❓ — inspect with `bsdtar -tf` first

**Recommended route:** wrap it in a PKGBUILD (see [6a](#6a-packaging-a-binary-tarball)) · below is the manual install, for temporary trials

#### Step 1: Download + verify the checksum

```bash
mkdir -p ~/build/jbtb && cd ~/build/jbtb
V=3.9.1.89198
curl -fLO "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${V}.tar.gz"
curl -fLO "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${V}.tar.gz.sha256"
sha256sum -c "jetbrains-toolbox-${V}.tar.gz.sha256"   # must print OK
# if the .sha256 file isn't in "hash  filename" format, compare by eye:
# cat *.sha256; sha256sum jetbrains-toolbox-${V}.tar.gz
```

#### Step 2: Extract to `/opt/<app>` (system-wide) or `~/.local/opt/<app>` (single user)

```bash
# Single-user — no sudo, doesn't touch system files at all
mkdir -p ~/.local/opt/jetbrains-toolbox
bsdtar -xf "jetbrains-toolbox-${V}.tar.gz" -C ~/.local/opt/jetbrains-toolbox --strip-components 1

# System-wide
sudo mkdir -p /opt/jetbrains-toolbox
sudo bsdtar -xf "jetbrains-toolbox-${V}.tar.gz" -C /opt/jetbrains-toolbox --strip-components 1
```

Why `/opt` or `~/.local/opt`: ArchWiki states that packages **must not** install into `/usr/local`, and that `/opt/<pkg>` is used for large self-contained software ⚠️ search snippet only [Arch package guidelines](https://wiki.archlinux.org/title/Arch_package_guidelines) — so `/usr/local` and `/opt` are places pacman doesn't use (or uses little), which lets you install by hand without colliding with packages

> Caution: an app that **updates itself** can't overwrite root-owned files in `/opt` → if the app self-updates, install it under `~/.local/opt` (author's analysis)

#### Step 3: Symlink into PATH

```bash
# Find the real executable first
find ~/.local/opt/jetbrains-toolbox -maxdepth 2 -type f -perm -u+x

mkdir -p ~/.local/bin
ln -s ~/.local/opt/jetbrains-toolbox/bin/jetbrains-toolbox ~/.local/bin/jetbrains-toolbox   # example path
# System-wide:
# sudo ln -s /opt/jetbrains-toolbox/bin/jetbrains-toolbox /usr/local/bin/jetbrains-toolbox

# Check that ~/.local/bin is in PATH
echo "$PATH" | tr : '\n' | grep -x "$HOME/.local/bin" || echo 'Not in PATH yet — add it in ~/.bashrc or ~/.profile'
```

#### Step 4: `.desktop` file + icon

```bash
mkdir -p ~/.local/share/applications ~/.local/share/icons/hicolor/256x256/apps
cp ~/.local/opt/jetbrains-toolbox/<path-to-icon>.png \
   ~/.local/share/icons/hicolor/256x256/apps/jetbrains-toolbox.png      # if the tarball ships an icon

cat > ~/.local/share/applications/jetbrains-toolbox.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Exec=jetbrains-toolbox %u
Icon=jetbrains-toolbox
Terminal=false
Categories=Development;
EOF

desktop-file-validate ~/.local/share/applications/jetbrains-toolbox.desktop   # from desktop-file-utils [extra]
update-desktop-database ~/.local/share/applications                          # usually the DE picks it up by itself
```

- ⚠️ user desktop entries live in `~/.local/share/applications/` and take precedence over the system ones · `desktop-file-validate` is in `desktop-file-utils` — search snippet only [Desktop entries](https://wiki.archlinux.org/title/Desktop_entries) · checked 2026-11-06
- ⚠️ the `hicolor/256x256/apps` icon path follows freedesktop icon theme practice (the author didn't open the spec to confirm this time) — if it doesn't show up, use `Icon=/absolute/path/to/icon.png` instead

#### Step 5: Check dependencies, then find packages with `pacman -F`

```bash
BIN=~/.local/opt/jetbrains-toolbox/bin/jetbrains-toolbox

# Safer than ldd: only reads headers, runs no code
readelf -d "$BIN" | grep NEEDED
objdump -p "$BIN" | grep NEEDED

# Find missing .so files (ldd can execute code — only use it on binaries you already trust)
ldd "$BIN" | grep 'not found'

# Map .so names → Arch packages
sudo pacman -Fy
for lib in $(readelf -d "$BIN" | awk '/NEEDED/{gsub(/[\[\]]/,"",$5); print $5}'); do
  printf '%-30s ' "$lib"; pacman -F -q "$lib" | head -1
done
```

- ✅ the `ldd` man page warns that you "should never employ ldd on an untrusted executable" because it may execute code, and recommends `objdump -p ... | grep NEEDED` instead (shows direct dependencies only) — [ldd(1)](https://man.archlinux.org/man/ldd.1) · checked 2026-11-06
- `readelf`/`objdump`/`ar` are in `binutils` [core] ✅

#### Step 6: Remove

```bash
rm -rf ~/.local/opt/jetbrains-toolbox
rm -f ~/.local/bin/jetbrains-toolbox \
      ~/.local/share/applications/jetbrains-toolbox.desktop \
      ~/.local/share/icons/hicolor/256x256/apps/jetbrains-toolbox.png
update-desktop-database ~/.local/share/applications
# the app's config/cache usually lives in ~/.config, ~/.local/share, ~/.cache — delete as needed
```

### 3B. Source code

> **Real example (not tested):** GNU Hello `hello-2.12.3.tar.gz` (2026-03-17) with `hello-2.12.3.tar.gz.sig` ✅ [ftp.gnu.org/gnu/hello](https://ftp.gnu.org/gnu/hello/) · checked 2026-11-06 — a good autotools project to practice on

#### Why you **shouldn't `sudo make install` into `/usr`**

1. pacman doesn't know who owns those files → `pacman -Qo` can't find an owner, and you can't remove them (many Makefiles have no `uninstall` target)
2. If you overwrite files that belong to a package: the next package update overwrites them back, or your files break the existing library
3. If you later install a package containing a file with the same name, pacman stops with "conflicting files" and **deliberately won't overwrite it** · ArchWiki says manually installed software (e.g. `make install`) should be removed along with all its files before installing via pacman ⚠️ search snippet only [pacman](https://wiki.archlinux.org/title/Pacman) · checked 2026-11-06
4. pacman's `--overwrite` is an escape hatch that bypasses the file-conflict check ✅ [pacman(8)](https://man.archlinux.org/man/pacman.8) — ArchWiki uses it only for cases of broken metadata ⚠️ search snippet only — **don't use it to fix problems you created yourself**

(Items 1–2 are the author's analysis based on pacman's behavior)

**Recommended order:** wrap it in a PKGBUILD ([6c](#6c-building-from-source)) > `--prefix=/usr/local` or `~/.local` + Stow > plain install into `/usr/local`

#### autotools

```bash
cd ~/build && bsdtar -xf ~/Downloads/hello-2.12.3.tar.gz && cd hello-2.12.3
./configure --prefix=/usr/local          # or --prefix="$HOME/.local" (no sudo needed)
make -j"$(nproc)"
make check                               # if available

# stage before the real install: see which files it will install
make DESTDIR="$PWD/_stage" install
find _stage -type f -o -type l | sed "s|^_stage||" | tee ../hello-2.12.3.files

sudo make install                        # installs to /usr/local per the prefix
```

#### CMake

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build -j"$(nproc)"
DESTDIR="$PWD/_stage" cmake --install build      # staging
sudo cmake --install build
# CMake writes build/install_manifest.txt = list of installed files (keep it for removal)
```

✅ `DESTDIR` in CMake: installs into `<DESTDIR><prefix>`, e.g. `make DESTDIR=/package/stage install` → `/package/stage/usr/local` — [CMake DESTDIR](https://cmake.org/cmake/help/latest/envvar/DESTDIR.html) · checked 2026-11-06
⚠️ `install_manifest.txt` comes from the author's own knowledge; no document was opened to confirm it this time

#### Meson

```bash
meson setup build --prefix=/usr/local --buildtype=release
meson compile -C build
meson install -C build --destdir "$PWD/_stage"    # staging (--destdir available since Meson 0.57.0)
sudo meson install -C build
```

✅ `DESTDIR=/path meson install` or `--destdir` (since 0.57.0) — [Meson: Installing](https://mesonbuild.com/Installing.html) · checked 2026-11-06

#### Plain Makefile (no configure)

```bash
grep -nE '^(PREFIX|prefix|DESTDIR|BINDIR)\b' Makefile    # see which variables it supports
make -j"$(nproc)"
make PREFIX=/usr/local DESTDIR="$PWD/_stage" install     # if the Makefile supports them
# if it supports neither PREFIX nor DESTDIR: install it yourself with install(1)
sudo install -Dm755 ./myprog /usr/local/bin/myprog
```

#### GNU Stow (an easy-to-remove option)

`stow` 2.4.1-1 is in **[extra]** ✅ Concept: install each program into its own directory under the stow directory, then Stow creates symlinks into the target ✅ [GNU Stow manual](https://www.gnu.org/software/stow/manual/stow.html)

```bash
sudo pacman -S --needed stow

./configure --prefix=/usr/local          # the "real" prefix the program will know about
make -j"$(nproc)"
sudo make DESTDIR=/usr/local/stow/hello-2.12.3 install
# files end up in /usr/local/stow/hello-2.12.3/usr/local/... → move them up a level to match the stow layout:
sudo sh -c 'cd /usr/local/stow/hello-2.12.3 && mv usr/local/* . && rm -r usr'

cd /usr/local/stow
sudo stow hello-2.12.3        # creates symlinks in /usr/local (target = parent of the stow dir)
sudo stow -D hello-2.12.3     # remove: deletes only this package's symlinks
sudo rm -rf hello-2.12.3
```

---

## 4. .deb on Arch

> **Real examples (not tested):**
> - Google Chrome: `https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb` ⚠️ (URL seen in several external articles, not directly on a Google page) · not in the official repos ✅ [archlinux.org/packages](https://archlinux.org/packages/?q=chrome) · Google's signing key is `EB4C 1BFD 4F04 2F6D DDCC EC91 7721 F63B D38B 4796` ✅ [google.com/linuxrepositories](https://www.google.com/linuxrepositories/)
> - LM Studio: the download page offers an AppImage and a .deb (0.4.28) ✅ [lmstudio.ai/download](https://lmstudio.ai/download?os=linux) · not in the official repos ✅ · checked 2026-11-06

### .deb file structure

✅ A .deb is an **ar archive** with 3 members that "must occur in this exact order": `debian-binary` (value `2.0`) → `control.tar[.gz|.xz|.zst]` (metadata + maintainer scripts) → `data.tar[.gz|.xz|.zst|.bz2|.lzma]` (the files to be installed) — [deb(5)](https://manpages.debian.org/unstable/dpkg-dev/deb.5.en.html) · checked 2026-11-06

### Extract and inspect

```bash
mkdir -p ~/build/deb-chrome && cd ~/build/deb-chrome
curl -fL -o chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

# Method 1: ar (binutils [core])
ar t chrome.deb               # debian-binary, control.tar.xz, data.tar.xz (example)
ar x chrome.deb

# Method 2: bsdtar (libarchive [core]) — can read ar archives
bsdtar -xf chrome.deb

# Look at the files to be installed, and the metadata
bsdtar -tf data.tar.*  | head -40
mkdir control && bsdtar -xf control.tar.* -C control
cat control/control                   # Package, Version, Depends, ...
ls control/                           # preinst/postinst/prerm/postrm if present
```

✅ libarchive reads "GNU and BSD 'ar' archives" — [libarchive README](https://raw.githubusercontent.com/libarchive/libarchive/master/README.md) (it doesn't mention .deb directly, but a .deb is an ar archive per deb(5))

### Mapping `control` dependencies to Arch package names

✅ `Depends` format: comma-separated = every group is required (AND), `|` = alternatives (OR), version in parentheses `(>= 2.34)`, `:arch` is an architecture qualifier — [deb-control(5)](https://manpages.debian.org/unstable/dpkg-dev/deb-control.5.en.html)

Debian package names don't match Arch's (e.g. `libc6` ≈ `glibc`). A more accurate approach than guessing names is to **look at the .so files the binary actually needs, then use `pacman -F`**:

```bash
grep -E '^(Pre-)?Depends:' control/control | tr ',' '\n'

mkdir root && bsdtar -xf data.tar.* -C root
sudo pacman -Fy
find root -type f -exec sh -c 'file -b "$1" | grep -q ELF && readelf -d "$1" 2>/dev/null' _ {} \; \
  | awk '/NEEDED/{gsub(/[\[\]]/,"",$5); print $5}' | sort -u \
  | while read -r lib; do
      # skip libs already bundled with the package
      find root -name "$lib" -print -quit | grep -q . && continue
      printf '%-32s %s\n' "$lib" "$(pacman -F -q "$lib" | head -1)"
    done
```

### debtap

- ❌ Not in the official repos — searching `debtap` on archlinux.org/packages gives 0 results ✅ (checked 2026-11-06)
- ⚠️ It's in the **AUR** (the AUR page couldn't be opened due to Anubis, but the upstream README and external articles agree) — [github.com/helixarch/debtap](https://github.com/helixarch/debtap)
- ⚠️ The developer says to use official packages or write a PKGBUILD first; debtap is a fallback (search snippet only, of the README)
- **The non-AUR route:** write a PKGBUILD as in [6b](#6b-packaging-a-deb) — it does the same thing as debtap, but you control every line

### Risks of .deb on Arch

| Risk | Explanation | Mitigation |
|---|---|---|
| glibc / library version | A .deb is built for a specific Debian/Ubuntu release. Arch is rolling, so glibc is usually newer (old binaries usually run on a newer glibc, but not the other way round), but other libraries (e.g. ICU, OpenSSL, libffi) whose soname changed won't be found | use `readelf -d` + `pacman -F` · if not found → distrobox |
| Maintainer scripts don't run | `preinst`/`postinst`/`prerm`/`postrm` in `control.tar` don't run when you extract by hand (no dpkg); they may create users, set setuid, run `update-alternatives`, add an APT repo/key | **read every file**, then do the necessary parts yourself in the PKGBUILD's `package()` or `.install` · skip anything APT-related |
| Debian-specific files | may include cron jobs / files under `/etc/apt` / docs in `/usr/share/doc` | delete them in `package()` |
| Paths that don't match Arch | e.g. `/lib/x86_64-linux-gnu`, `/usr/lib/x86_64-linux-gnu` | move into `/usr/lib`, or keep under `/opt/<app>` and use RPATH (`patchelf`) |

(This table is the author's analysis, based on the structure from deb(5)/deb-control(5))

---

## 5. .rpm on Arch

> **Real example (not tested):** Google Chrome also ships an `.rpm` (`https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm` ⚠️ URL from external articles) · Google states that RPMs have been signed with a subkey of `0xD38B4796` since early 2023 ✅ [google.com/linuxrepositories](https://www.google.com/linuxrepositories/) · AppImageLauncher v3.0.0-beta-3 (2025-10-28) also ships an `.rpm` ✅ [GitHub releases API](https://api.github.com/repos/TheAssassin/AppImageLauncher/releases/latest)

### Tools (all in the official repos)

| Method | Package | Repo |
|---|---|---|
| `bsdtar -xf file.rpm` | `libarchive` | [core] ✅ libarchive handles "files with RPM wrapper" |
| `rpm2cpio file.rpm \| cpio -idmv` | `rpmextract` or `rpm-tools` + `cpio` | [extra] ✅ |
| `rpmextract.sh file.rpm` | `rpmextract` | [extra] ✅ |
| `rpm2archive`, `rpm -qp --requires` | `rpm-tools` | [extra] ✅ |

```bash
mkdir -p ~/build/rpm-chrome/root && cd ~/build/rpm-chrome
curl -fL -o chrome.rpm https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm

# Method 1 (nothing extra to install)
bsdtar -xf chrome.rpm -C root

# Method 2
sudo pacman -S --needed rpmextract cpio
( cd root && rpm2cpio ../chrome.rpm | cpio -idmv )

# Read metadata / dependencies / scriptlets (needs rpm-tools)
sudo pacman -S --needed rpm-tools
rpm -qip chrome.rpm                 # package info
rpm -qp --requires chrome.rpm       # dependencies (often .so names or capabilities)
rpm -qp --scripts chrome.rpm        # %pre/%post/%preun/%postun — not run when extracting by hand
rpm -qlp chrome.rpm                 # file list

# Verify the signature (import the vendor key first — the key goes into the user's rpm db, doesn't affect pacman)
curl -fLO https://dl.google.com/linux/linux_signing_key.pub
rpmkeys --import linux_signing_key.pub      # may need --dbpath pointing to a user dir, see rpmkeys(8)
rpm --checksig -v chrome.rpm
```

- ✅ `rpm-tools` 6.0.1-2 contains `rpm2cpio`, `rpm2archive`, `rpm`, `rpmkeys`, etc. — [file list](https://archlinux.org/packages/extra/x86_64/rpm-tools/files/) · ✅ `rpmextract` 1.0-11 contains `rpm2cpio`, `rpmextract.sh` — [file list](https://archlinux.org/packages/extra/any/rpmextract/files/) · checked 2026-11-06
- ❓ Where `rpmkeys` imports keys to on Arch (which rpm database) and whether it needs sudo has not been checked — an easier workaround is to verify inside a Fedora distrobox

**Caveats:** all the same as for .deb (glibc/library, scriptlets not run, Fedora-style paths such as `/usr/lib64` must be moved to `/usr/lib`) · packaging as a PKGBUILD works like [6b](#6b-packaging-a-deb), except in `package()` you use `bsdtar -xf "$srcdir/<file>.rpm" -C "$pkgdir"` (put the .rpm in `noextract=()` if you don't want makepkg to extract it itself)

---

## 6. The most "Arch-correct" way: write your own PKGBUILD

**No AUR needed at all** — the AUR is just a place to host PKGBUILDs; `makepkg`, which builds the package, is in `pacman` [core] ✅

### 6.0 Step by step: first PKGBUILD → `makepkg -si` → install / verify / update / remove with pacman

> Added 2026-11-06 at the user's request · behavior cited from [makepkg(8)](https://man.archlinux.org/man/makepkg.8), [PKGBUILD(5)](https://man.archlinux.org/man/PKGBUILD.5), [pacman(8)](https://man.archlinux.org/man/pacman.8) · ⚠️ not yet run/tested on a real Arch system (the machine it was written on runs Windows)
>
> This example is meant to be **followable immediately without downloading anything** — it packages a single shell script so you see the whole flow first, then you apply templates 6a / 6b / 6c to real software

#### Step 1 — Install the tools (once)

```bash
sudo pacman -S --needed base-devel pacman-contrib namcap
# base-devel   = makepkg (comes with pacman), fakeroot, gcc, make, etc.
# pacman-contrib = updpkgsums   ·   namcap = PKGBUILD/package linter  (these two are not in base-devel)
```

#### Step 2 — Prepare the folder and source

Use 1 folder per package (recommended: keep them all in `~/pkgbuilds/` and make it a git repo, so you can look back at what you changed)

```bash
mkdir -p ~/pkgbuilds/hello-local && cd ~/pkgbuilds/hello-local

cat > hello-local.sh <<'EOF'
#!/usr/bin/env bash
echo "hello from a package I built myself"
EOF
```

#### Step 3 — Write the PKGBUILD

You can start from an empty file, or copy the template that ships with pacman:

```bash
cp /usr/share/pacman/PKGBUILD.proto PKGBUILD   # official template with every variable and comments (delete what you don't use)
ls /usr/share/pacman/                           # PKGBUILD-split.proto and PKGBUILD-vcs.proto are there too
```

Minimal PKGBUILD for this example:

```bash
pkgname=hello-local          # package name (lowercase, must not clash with a repo package you don't intend to replace)
pkgver=1.0.0                 # program version (no - : / or spaces)
pkgrel=1                     # PKGBUILD revision — if only the packaging changes, bump this by 1
pkgdesc="Example: my first locally built package"
arch=('any')                 # script is CPU-independent → any · binaries use 'x86_64'
license=('MIT')              # use the SPDX name
depends=('bash')             # what's needed at "run" time  (for build time use makedepends)
source=('hello-local.sh')    # a local file or a URL
sha256sums=('SKIP')          # in step 4, updpkgsums will write the real value instead

package() {
  # everything placed under "$pkgdir" = files pacman will install and track
  install -Dm755 "$srcdir/hello-local.sh" "$pkgdir/usr/bin/hello-local"
}
```

The principle of `package()`: **never touch the real system** — write only into `"$pkgdir"` (makepkg runs this part under `fakeroot`) · if you need to build first, add `build()` (see 6c) · `install -D` = create parent directories automatically, `-m755` = file permissions

#### Step 4 — Add checksums and lint

```bash
updpkgsums           # computes sha256 of every file in source=() and writes it into the PKGBUILD
namcap PKGBUILD      # warns about missing/malformed variables
```

#### Step 5 — Build + install: `makepkg -si`

```bash
makepkg -si          # run as a normal user, never with sudo (makepkg refuses to run as root)
```

What happens, in order:
1. Check dependencies — `-s` (`--syncdeps`) installs missing ones from the official repos via pacman (will ask for sudo)
2. Download/copy the source → verify checksums (and PGP if there's a `.sig`) → extract into `src/`
3. Run `prepare()` → `build()` → `check()` (if present) → `package()` into `pkg/`
4. Compress into `hello-local-1.0.0-1-any.pkg.tar.zst` in this folder (the extension depends on `PKGEXT` in `/etc/makepkg.conf`)
5. `-i` (`--install`) = calls `pacman -U` on that file for you (will ask for sudo and confirmation)

You can also split it into two steps (useful when you want to inspect the files before installing):

```bash
makepkg -s                                   # build only
namcap hello-local-1.0.0-1-any.pkg.tar.zst   # lint the resulting package
bsdtar -tf hello-local-1.0.0-1-any.pkg.tar.zst   # see where the files will go
sudo pacman -U ./hello-local-1.0.0-1-any.pkg.tar.zst   # install (needs ./ or a full path)
```

#### Step 6 — Verify it's really installed

```bash
hello-local                      # try running it
pacman -Qi hello-local           # package info: version, depends, install date
pacman -Ql hello-local           # every file this package owns
pacman -Qo /usr/bin/hello-local  # which package owns this file
pacman -Qk hello-local           # check that all files are still present
pacman -Qm                       # all packages not from a repo = everything you packaged yourself
```

#### Step 7 — Update

| Situation | What to change in the PKGBUILD | Command |
|---|---|---|
| upstream releases a new version | new `pkgver=` + `pkgrel=1` | `updpkgsums && makepkg -si` |
| packaging changed (same program version) | `pkgrel` +1 | `makepkg -si` (if you changed files in `source=()`, run `updpkgsums` first) |
| rebuild the exact same version | no change | `makepkg -sif` (`-f` = overwrite the existing `.pkg.tar.*` file) |

pacman sees a newer version → it's a normal upgrade, no need to remove first · **downgrade**: keep the old `.pkg.tar.zst` files, then `sudo pacman -U ./old-file` (pacman warns that it's a downgrade and asks for confirmation)

⚠️ Self-built packages **are not updated by `pacman -Syu`** — you have to track new versions yourself (`pacman -Qm` is the list to watch) · for how to know there's a new version, and cases where you must rebuild even though upstream hasn't released, see [15.2](#152-self-packaged-pkgbuilds-tarball--deb--rpm--source--6a6c)

#### Step 8 — Remove

```bash
sudo pacman -R hello-local      # remove the package (deletes every file listed in pacman -Ql)
sudo pacman -Rs hello-local     # + remove dependencies installed for it that nothing else uses
sudo pacman -Rns hello-local    # + don't keep config backups as .pacsave (cleanest removal)

pacman -Qdt                     # check for leftover orphans (dependencies nothing uses)
```

Clean up the working folder after building: `makepkg -c` (at build time) or `rm -rf src pkg` · you can keep the `.pkg.tar.zst` files for downgrades

#### Common errors

| Message | Cause | Fix |
|---|---|---|
| `Running makepkg as root is not allowed` | used `sudo makepkg` | run as a normal user |
| `One or more files did not pass the validity check!` | checksum mismatch (you edited a file / upstream changed the file) | first verify the file comes from the real source, then `updpkgsums` |
| `One or more PGP signatures could not be verified!` | you don't have the signer's public key yet | confirm the fingerprint from an official source first, then `gpg --recv-keys <FINGERPRINT>` (see section 10) |
| `... exists in filesystem` (conflicting files) | there's already a file at that path | `pacman -Qo <path>` to see who owns it · if it's from a manual install, delete the old one — **don't use `--overwrite`** |
| Package installs but won't run (`error while loading shared libraries`) | incomplete `depends=()` | `namcap ./*.pkg.tar.*` + `pacman -F <libname.so>`, then add to `depends` |

#### Short summary

```bash
cd ~/pkgbuilds/<name>  →  write PKGBUILD  →  updpkgsums  →  namcap PKGBUILD  →  makepkg -si
verify:  pacman -Qi / -Ql / -Qo / -Qm        remove:  sudo pacman -Rns <name>
```

From here, apply the templates below to real software: **6a** tarball · **6b** .deb · **6c** source (for .rpm use 6b but change `package()` to `bsdtar -xf "$srcdir/X.rpm" -C "$pkgdir"` and add `noextract=('X.rpm')`)

### Why it's worth it

- All files are tracked by pacman → `pacman -Ql`, `pacman -Qo`, `pacman -Qk` work
- Removal with `pacman -R`: "Files belonging to the specified package will be deleted" ✅ [pacman(8)](https://man.archlinux.org/man/pacman.8)
- pacman checks for file conflicts before installing (doesn't overwrite other packages' files)
- `pacman -U` pulls dependencies from the sync repos automatically ✅ [pacman(8)](https://man.archlinux.org/man/pacman.8)
- `pacman -Qm` shows packages not in the sync database = a list of everything you packaged yourself ✅ [pacman(8)](https://man.archlinux.org/man/pacman.8)
- Trade-off: you must update `pkgver` + checksums yourself when upstream releases a new version (`nvchecker` or RSS can help — nvchecker's repo was not checked this time ❓)

### Tools (repos checked 2026-11-06)

| Command | Package | In `base-devel`? |
|---|---|---|
| `makepkg`, `makepkg -g` | `pacman` [core] | yes (base-devel depends on pacman) ✅ |
| `fakeroot` | `fakeroot` | yes ✅ |
| `updpkgsums` | `pacman-contrib` [extra] | **no** ✅ |
| `namcap` | `namcap` [extra] | **no** ✅ |
| `bsdtar` | `libarchive` [core] | not in base-devel's direct depends list, but pacman needs it anyway ⚠️ (author's inference) |

### Standard workflow

```bash
mkdir -p ~/pkgbuilds/<name> && cd ~/pkgbuilds/<name>
$EDITOR PKGBUILD

updpkgsums                 # downloads the source and writes checksums into the PKGBUILD (pacman-contrib)
#   or: makepkg -g >> PKGBUILD   then delete the old checksum lines yourself
namcap PKGBUILD            # lint the PKGBUILD
makepkg -s                 # build (installs missing makedepends via pacman)
namcap ./*.pkg.tar.*       # lint the resulting package (missing/extra dependencies, misplaced files)
bsdtar -tf ./*.pkg.tar.* | less     # see where the files go

sudo pacman -U ./<name>-<ver>-<rel>-<arch>.pkg.tar.*    # install
# or build+install in one go: makepkg -si

# Remove
sudo pacman -R <name>      # or -Rs to also remove dependencies nothing else uses
```

Frequently used makepkg options ✅ [makepkg(8)](https://man.archlinux.org/man/makepkg.8):
- `-s` install missing dependencies via pacman · `-i` install after a successful build · `-r` (with `-s`) remove the dependencies makepkg installed after the build · `-c` clean up working files · `-C` remove `$srcdir` before building · `-f` overwrite an existing built package · `-o` download+extract+`prepare()` but don't build · `--verifysource` verify integrity only
- `--skippgpcheck`, `--skipchecksums`, `--skipinteg` = skip verification → **don't make a habit of it**
- ⚠️ makepkg refuses to run as root because a PKGBUILD can run arbitrary commands — search snippet only [makepkg](https://wiki.archlinux.org/title/Makepkg) · ✅ the man page has exit code 10 "User attempted to run makepkg as root"
- ⚠️ `base-devel` is always assumed to be installed; don't list it in `makedepends` · `namcap` is recommended for linting — search snippet only [PKGBUILD](https://wiki.archlinux.org/title/PKGBUILD)
- The output file extension is set by `PKGEXT` · the man page gives the compiled-in default as `.pkg.tar.gz` ✅ [makepkg.conf(5)](https://man.archlinux.org/man/makepkg.conf.5), but the system's `/etc/makepkg.conf` may set something else (check `grep PKGEXT /etc/makepkg.conf`) — so this guide writes `*.pkg.tar.*` · personal config goes in `$XDG_CONFIG_HOME/pacman/makepkg.conf` or `~/.makepkg.conf` ✅

The meaning of the PKGBUILD variables below was checked against ✅ [PKGBUILD(5)](https://man.archlinux.org/man/PKGBUILD.5): `pkgver` must not contain `:` `/` `-` or spaces · `source=('filename::url')` sets the name of the downloaded file · `'SKIP'` in a checksum slot = skip verification of that file · `validpgpkeys` = full uppercase fingerprints; if non-empty, only signatures from these keys are accepted · `package()` is mandatory and runs under fakeroot · `$srcdir` = where the source is extracted · `$pkgdir` = the package root, used only in `package()`

### 6a. Packaging a binary tarball

Example: JetBrains Toolbox (not tested — check the paths inside the tarball yourself)

```bash
# Maintainer: you (personal use)
pkgname=jetbrains-toolbox-bin            # -bin = package from a prebuilt binary (Arch convention)
pkgver=3.9.1.89198                       # upstream version (no - : /)
pkgrel=1                                 # our own PKGBUILD revision
pkgdesc="JetBrains Toolbox App (repackaged vendor tarball)"
arch=('x86_64')                          # architecture-specific binary
url="https://www.jetbrains.com/toolbox-app/"
license=('LicenseRef-proprietary')       # closed software — use the vendor's actual license name
depends=()                               # fill in from readelf + pacman -F + namcap results
options=('!strip')                       # don't strip the vendor's binary
source=("https://download.jetbrains.com/toolbox/jetbrains-toolbox-${pkgver}.tar.gz")
sha256sums=('put the real value from updpkgsums here and compare with the vendor .sha256 file')

package() {
  # after extraction it's at $srcdir/jetbrains-toolbox-$pkgver/ (assumed — check with bsdtar -tf)
  install -d "$pkgdir/opt/$pkgname"
  cp -a "$srcdir/jetbrains-toolbox-${pkgver}/." "$pkgdir/opt/$pkgname/"

  # PATH entry: symlink in /usr/bin (pacman owns it, so installing into /usr is correct)
  install -d "$pkgdir/usr/bin"
  ln -s "/opt/$pkgname/bin/jetbrains-toolbox" "$pkgdir/usr/bin/jetbrains-toolbox"

  # desktop entry (write jetbrains-toolbox.desktop next to the PKGBUILD and add it to source=())
  # install -Dm644 "$srcdir/jetbrains-toolbox.desktop" "$pkgdir/usr/share/applications/jetbrains-toolbox.desktop"
}
```

> Inside a package, `/usr` and `/opt` are fine because pacman owns the files · **no `/usr/local`** in packages ⚠️ search snippet only [Arch package guidelines](https://wiki.archlinux.org/title/Arch_package_guidelines)
> If the app self-updates (overwriting `/opt`), packaging it conflicts with that → disable auto-update in the app, or choose the `~/.local/opt` install instead

### 6b. Packaging a .deb

Example: Google Chrome (not tested)

```bash
pkgname=google-chrome-local
pkgver=0                                 # put the Version from control/control here (convert - to _ if present)
pkgrel=1
pkgdesc="Google Chrome (repackaged from vendor .deb)"
arch=('x86_64')
url="https://www.google.com/chrome/"
license=('LicenseRef-proprietary')
depends=()                               # mapped from Depends: in control + pacman -F results
options=('!strip')
# The "current" URL changes content on every new release → name the file after pkgver
# the checksum stops matching when Google releases a new version = signal to update pkgver
source=("chrome-${pkgver}.deb::https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb")
sha256sums=('put the real value here')

# makepkg extracts the .deb (ar) automatically with bsdtar → debian-binary, control.tar.*, data.tar.* in $srcdir

prepare() {
  # always read the maintainer scripts first (just list them, don't run them)
  mkdir -p "$srcdir/control"
  bsdtar -xf "$srcdir"/control.tar.* -C "$srcdir/control"
  ls "$srcdir/control"
}

package() {
  bsdtar -xf "$srcdir"/data.tar.* -C "$pkgdir"   # all files go into $pkgdir with the original layout

  # clean up Debian-specific stuff (check with bsdtar -tf data.tar.* first to see what's there)
  rm -rf "$pkgdir/etc/cron.daily"                # example: if there's a cron job that manages the APT repo
  # do what postinst does, "only as much as necessary", yourself, e.g. setuid permissions:
  # chmod 4755 "$pkgdir/opt/google/chrome/chrome-sandbox"   # only if postinst really does this
}
```

### 6c. Building from source

Example: GNU Hello 2.12.3 (autotools + GPG signature) (not tested)

```bash
pkgname=hello
pkgver=2.12.3
pkgrel=1
pkgdesc="GNU Hello, the friendly greeter"
arch=('x86_64')
url="https://www.gnu.org/software/hello/"
license=('GPL-3.0-or-later')             # check against the source's COPYING file
depends=('glibc')
makedepends=()                           # no need to list base-devel
source=("https://ftp.gnu.org/gnu/hello/hello-${pkgver}.tar.gz"{,.sig})   # tarball + .sig
sha256sums=('put the real value here'
            'SKIP')                      # the .sig file needs no checksum
validpgpkeys=('FULL_40_CHARACTER_UPPERCASE_FINGERPRINT')   # see section 10 for how to find and verify it

build() {
  cd "hello-${pkgver}"
  ./configure --prefix=/usr              # inside a package /usr is fine, because pacman manages it
  make
}

check() {
  cd "hello-${pkgver}"
  make check
}

package() {
  cd "hello-${pkgver}"
  make DESTDIR="$pkgdir" install         # staged into $pkgdir, doesn't touch the real system
}
```

For CMake/Meson in `package()`:

```bash
# CMake
build()   { cmake -S "$pkgname-$pkgver" -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release; cmake --build build; }
package() { DESTDIR="$pkgdir" cmake --install build; }

# Meson
build()   { meson setup build "$pkgname-$pkgver" --prefix=/usr --buildtype=release; meson compile -C build; }
package() { meson install -C build --destdir "$pkgdir"; }
```

⚠️ Arch has specific guidelines for CMake/Meson (e.g. build type and wrappers) that weren't checked this time because ArchWiki couldn't be opened — the above are generally applicable values

### Note: AUR / official PKGBUILDs are useful as "examples"

Not the main route, but it saves a lot of time: see how others solved the dependency/path/postinst problems of the same program, then write your own PKGBUILD while **reading every line** — don't copy and run it straight away

```bash
# Official repo PKGBUILDs (Arch GitLab) — pkgctl is in devtools [extra]
sudo pacman -S --needed devtools
pkgctl repo clone --protocol=https stow      # ✅ man: clone the packaging repo read-only over HTTPS
# or git clone https://aur.archlinux.org/<pkg>.git to read an AUR PKGBUILD (read only)
```

✅ `pkgctl repo clone` clones from the official namespace and has a read-only HTTPS mode — [pkgctl-repo-clone(1)](https://man.archlinux.org/man/pkgctl-repo-clone.1) (seen via search) · checked 2026-11-06

---

## 7. distrobox / podman

- ✅ `distrobox` 1.8.2.5-1 and `podman` 6.1.4-1 are in **[extra]** · the GUIs `boxbuddy`, `distroshelf` are also in [extra] — [archlinux.org/packages](https://archlinux.org/packages/?q=distrobox) · checked 2026-11-06
- ✅ Supported container managers: `podman`, `docker`, `lilipod` — [distrobox README](https://raw.githubusercontent.com/89luca89/distrobox/main/docs/README.md)
- ✅ **Not a sandbox**: "Isolation and sandboxing are **not** the main aims of the project" · the container can access home, USB, Wayland/X11, D-Bus, `/dev`, the SSH agent · a rootful container "can modify system stuff outside the container" — rootless podman is recommended — [distrobox README](https://raw.githubusercontent.com/89luca89/distrobox/main/docs/README.md)

**Good for:** .deb/.rpm that depend on specific Debian/Ubuntu/Fedora library versions · complex postinst scripts · tools the vendor only supports on Ubuntu LTS · using another distro's toolchain
**Not good for:** untrusted programs (no isolation), drivers/kernel modules, system-level services

> **Real example (not tested):** installing the LM Studio .deb in an Ubuntu box

```bash
sudo pacman -S --needed distrobox podman

# rootless podman needs subuid/subgid entries for the user (❓ not confirmed from ArchWiki this time)
grep "^$USER:" /etc/subuid /etc/subgid

distrobox create --image ubuntu:24.04 --name ubuntu       # --home ~/boxes/ubuntu if you don't want dotfiles mixed in
distrobox enter ubuntu

# --- inside the container ---
curl -fL -o /tmp/lmstudio.deb 'https://lmstudio.ai/download/latest/linux/x64?format=deb'
sudo apt install /tmp/lmstudio.deb             # apt installs dependencies + runs postinst for you
distrobox-export --app lm-studio               # check the real app/desktop file name with: ls /usr/share/applications
distrobox-export --bin /usr/bin/<binary> --export-path ~/.local/bin   # if it's a CLI
exit

# --- removal ---
distrobox enter ubuntu -- distrobox-export --app lm-studio --delete
distrobox rm ubuntu
```

✅ Syntax `distrobox-export --app <name|desktopfile> | --bin <path> [--export-path <dir>] [--delete]` — [distrobox-export docs](https://raw.githubusercontent.com/89luca89/distrobox/main/docs/usage/distrobox-export.md) · ✅ `distrobox create --image/-i --name/-n --home/-H --init --nvidia --unshare-all` — [distrobox-create docs](https://raw.githubusercontent.com/89luca89/distrobox/main/docs/usage/distrobox-create.md) · checked 2026-11-06

For .rpm: `distrobox create --image registry.fedoraproject.org/fedora-toolbox:<ver> --name fedora`, then `sudo dnf install ./file.rpm`

---

## 8. Flatpak / AppImage

### Flatpak

```bash
sudo pacman -S --needed flatpak         # [extra] 1:1.18.4-2 — the flathub remote is already included
# reboot (or log out/in) so XDG_DATA_DIRS gets updated, per Flathub's setup page

flatpak search spotify
flatpak install flathub com.spotify.Client
flatpak run com.spotify.Client
flatpak update
flatpak uninstall com.spotify.Client
flatpak uninstall --unused              # remove runtimes nothing uses

# Single-user (no root needed)
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub <app-id>
```

- ✅ The `flatpak` package contains `/usr/share/flatpak/remotes.d/flathub.flatpakrepo` — [file list](https://archlinux.org/packages/extra/x86_64/flatpak/files/) · ✅ steps on Arch: `sudo pacman -S flatpak`, then restart — [flathub.org/setup/Arch](https://flathub.org/setup/Arch) · ✅ install/run/update/uninstall/`--unused`/list commands — [Flatpak docs](https://docs.flatpak.org/en/latest/using-flatpak.html) · ⚠️ `--user` and the user-level remote-add command — search snippet only [ArchWiki Flatpak](https://wiki.archlinux.org/title/Flatpak) · checked 2026-11-06
- **Real example:** Spotify (`com.spotify.Client`) is not in the official repos (there's only `spotify-launcher`, which fetches from Spotify's apt repo) ✅ · on Flathub it's marked "Unverified" and "community-provided package ... not verified by, affiliated with, or supported by Spotify" ✅ [Flathub](https://flathub.org/apps/com.spotify.Client) → check for the Verified badge every time before installing
- Managing permissions: `flatseal` [extra], `flatpak-kcm` [extra] (KDE) ✅

### AppImage

```bash
sudo pacman -S --needed fuse2           # [extra] 2.9.9-6 — classic AppImages need FUSE 2
chmod +x ~/Applications/LM-Studio.AppImage
~/Applications/LM-Studio.AppImage

# No FUSE / running in a container: extract and run (slower, a last resort)
~/Applications/LM-Studio.AppImage --appimage-extract-and-run
APPIMAGE_EXTRACT_AND_RUN=1 ~/Applications/LM-Studio.AppImage
~/Applications/LM-Studio.AppImage --appimage-extract    # gives a squashfs-root/ folder (can be wrapped in a PKGBUILD)
```

- ✅ AppImage needs FUSE · on Arch install `fuse2` · without FUSE use `--appimage-extract-and-run` / `APPIMAGE_EXTRACT_AND_RUN=1` · `--appimage-extract` creates `squashfs-root` — [AppImage docs: FUSE](https://docs.appimage.org/user-guide/troubleshooting/fuse.html) · checked 2026-11-06
- **Real example:** LM Studio ships an AppImage ✅ [lmstudio.ai](https://lmstudio.ai/download?os=linux)
- **AppImage managers:**
  - **Gear Lever** (`it.mijorus.gearlever`) — not in the official repos ✅ · available on **Flathub**, version 4.6.2 ✅ [Flathub](https://flathub.org/apps/it.mijorus.gearlever) → `flatpak install flathub it.mijorus.gearlever` (**the non-AUR route**)
  - **AppImageLauncher** — for Arch, upstream points to the **AUR** (`appimagelauncher`, `appimagelauncher-git`) ⚠️ [README](https://github.com/TheAssassin/AppImageLauncher) · not in the official repos ✅ · latest release v3.0.0-beta-3 (2025-10-28, still beta) includes a "lite" AppImage ✅ [releases API](https://api.github.com/repos/TheAssassin/AppImageLauncher/releases/latest) → you can use the lite AppImage without going through the AUR (not tested)
- AppImage has **no sandbox** and no central update mechanism

---

## 9. Other channels

| Channel | Install the tool itself (official repo) | Installs where | Advantages on Arch | Drawbacks/risks |
|---|---|---|---|---|
| **pipx** | `python-pipx` [extra] ✅ | `~/.local/bin` (change with `PIPX_BIN_DIR`) ✅ [pipx: configure paths](https://pipx.pypa.io/latest/how-to/configure-paths/) | a separate venv per app, doesn't clash with `/usr/lib/python*` | when Arch's Python gets a major version bump, venvs may break and need `pipx reinstall-all` (author's analysis ❓ not confirmed) |
| **cargo install** | `rust` or `rustup` [extra] ✅ | `$HOME/.cargo/bin` (or `--root`, `CARGO_INSTALL_ROOT`) ✅ [cargo-install](https://doc.rust-lang.org/cargo/commands/cargo-install.html) | static-ish binaries, doesn't touch the system | doesn't update itself · `--locked` = use the Cargo.lock shipped with the package (reproducible, but you don't get dependency fixes) ✅ |
| **npm -g** | `npm` [extra] ✅ | set `npm_config_prefix=~/.local` and add `~/.local/bin` to PATH ⚠️ search snippet only [ArchWiki Node.js](https://wiki.archlinux.org/title/Nodejs) | no sudo needed, doesn't overwrite `/usr/lib/node_modules` | high npm supply-chain risk (package install scripts run at install time) |
| **go install** | `go` [extra] ✅ | `GOBIN` → `$GOPATH/bin` → `$HOME/go/bin` · `go install example.com/pkg@v1.2.3` ✅ [go command](https://pkg.go.dev/cmd/go#hdr-Compile_and_install_packages_and_dependencies) | single binary | no uninstall — delete the file yourself |
| **Homebrew on Linux** | not in the official repos ⚠️ · requires `base-devel procps-ng curl file git` ✅ | `/home/linuxbrew/.linuxbrew` ✅ [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux) | lots of formulae, doesn't touch `/usr` | installed via `curl ... install.sh \| bash` ✅ [brew.sh](https://brew.sh/) (read the script first) · a second toolchain/library set layered over Arch's · don't let brew come before `/usr/bin` in the PATH used for builds (author's analysis) |
| **Nix** | `nix` 2.35.4-1 [extra] ✅ | `/nix/store` | reproducible, rollback, huge nixpkgs, installable straight from pacman | GUI/OpenGL for nixpkgs apps on non-NixOS systems may need extra setup (❓ not checked) · uses disk space · steep learning curve |

```bash
# pipx
sudo pacman -S --needed python-pipx
pipx ensurepath                  # adds ~/.local/bin to PATH (you can check with --dry-run first)
pipx install <tool> ; pipx uninstall <tool>

# cargo
cargo install --locked ripgrep   # (ripgrep is already in the repos — always check pacman -Ss first)
cargo uninstall ripgrep

# npm without sudo
echo 'export npm_config_prefix="$HOME/.local"' >> ~/.profile
npm install -g <pkg> ; npm uninstall -g <pkg>

# go
go install example.com/cmd/tool@latest ; rm "$(go env GOPATH)/bin/tool"

# Nix (from the official repos)
sudo pacman -S --needed nix
sudo systemctl enable --now nix-daemon.service
```

- ⚠️ ArchWiki says the system pip is set up as an "externally managed environment" (PEP 668), so it refuses system-level installs · pipx suits packages that have a CLI entrypoint — search snippet only [ArchWiki Python](https://wiki.archlinux.org/title/Python)
- 🗣️ Whether Nix on Arch requires adding the user to the `nix-users` group: on the Talk:Nix page one editor says the Arch package no longer creates this group since 2.26.3-2 and it works without being in the group; another says you do need it (not fully tested) · the main article doesn't mention this group — ⚠️ search snippet only [Nix](https://wiki.archlinux.org/title/Nix), [Talk:Nix](https://wiki.archlinux.org/title/Talk:Nix) · check your own machine with `getent group nix-users`

---

## 10. Security

### Verify checksums

```bash
sha256sum -c app.tar.gz.sha256          # vendor provides a .sha256 file (e.g. JetBrains)
sha256sum app.tar.gz                    # compare by eye with the value published on the vendor's HTTPS page
```

A checksum only verifies that the file wasn't corrupted in transit. If the file and the checksum come from the same server, anyone who compromises the server can modify both → a GPG signature is better (author's analysis)

### Verify GPG signatures

```bash
cd ~/build/hello
curl -fLO https://ftp.gnu.org/gnu/hello/hello-2.12.3.tar.gz
curl -fLO https://ftp.gnu.org/gnu/hello/hello-2.12.3.tar.gz.sig

# The first time you'll get "Can't check signature: No public key" along with the key's fingerprint/ID
gpg --verify hello-2.12.3.tar.gz.sig hello-2.12.3.tar.gz

# Option 1: use the GNU keyring (ftp.gnu.org/gnu/gnu-keyring.gpg really exists ✅)
curl -fLO https://ftp.gnu.org/gnu/gnu-keyring.gpg
gpg --no-default-keyring --keyring ./gnu-keyring.gpg --verify hello-2.12.3.tar.gz.sig hello-2.12.3.tar.gz

# Option 2: fetch the key by full fingerprint, then compare the fingerprint against a second source (project page/release announcement)
gpg --recv-keys <FULL_FINGERPRINT>
gpg --verify hello-2.12.3.tar.gz.sig hello-2.12.3.tar.gz   # must print "Good signature"
```

In a PKGBUILD: put the `.sig` file in `source=()` (checksum `'SKIP'`) and the fingerprint in `validpgpkeys=()` — makepkg verifies the signature every time and only accepts keys on the list ✅ [PKGBUILD(5)](https://man.archlinux.org/man/PKGBUILD.5) · the key must be in the keyring of the user running makepkg (`gpg --recv-keys`)

> ⚠️ `gnu-keyring.gpg` is downloaded from the same server as the tarball — better than not verifying, but not an independent trust chain · ❓ the fingerprint of the hello-2.12.3 signer has not been checked; read it from your own `gpg --verify` output

### Don't run install scripts from the web without reading them

```bash
# Instead of: curl -fsSL https://example.com/install.sh | bash
curl -fsSL -o install.sh https://example.com/install.sh
less install.sh            # see where it writes files, whether it uses sudo, what else it downloads, whether it edits PATH/shell rc
bash install.sh
```

Scripts like this often write directly into `/usr/bin` or `/usr/lib` (overwriting pacman's files), add systemd units, or edit `~/.bashrc` (author's analysis)

### Don't overwrite pacman-managed files in `/usr`

```bash
pacman -Qo /usr/bin/foo            # ✅ shows the package that owns the file
pacman -Qkk                        # ✅ checks every package's files (permission/size/mtime if there's an mtree)
pacman -Qm                         # ✅ packages not in the sync db = everything you packaged yourself

# Before a manual install: check whether the files to be installed already have an owner
while read -r f; do pacman -Qo "$f" 2>/dev/null; done < hello-2.12.3.files

# Find files in /usr not owned by any package (orphan files) — may be slow
comm -23 <(sudo find /usr -xdev -type f | sort) <(pacman -Qlq | sort -u)
```

✅ `-Qo`, `-Qk`/`-Qkk`, `-Qm` — [pacman(8)](https://man.archlinux.org/man/pacman.8) · ⚠️ if you hit "conflicting files", check `pacman -Qo` first; only move the file away if it has no owner — search snippet only [pacman](https://wiki.archlinux.org/title/Pacman)

### Keep a list of manual installs for later removal

```bash
# ~/.local/share/manual-installs/<app>.files = file list from the DESTDIR staging (section 3B)
mkdir -p ~/.local/share/manual-installs
cp hello-2.12.3.files ~/.local/share/manual-installs/
echo "$(date -I) hello 2.12.3 /usr/local (configure --prefix=/usr/local)" >> ~/.local/share/manual-installs/LOG

# Remove using the list (check the list by eye first!)
xargs -d '\n' -a ~/.local/share/manual-installs/hello-2.12.3.files sudo rm -v --
```

Better than keeping notes yourself: Stow (`/usr/local/stow/<app>`) or packaging as a PKGBUILD (`pacman -Qm` gives you the list automatically)

---

## 11. Assumptions

- x86_64 architecture · Arch Linux fully up to date (rolling) as of 2026-11-06 · uses systemd
- "Without the AUR" = not installing packages/AUR helpers from the AUR · **reading** PKGBUILDs on the AUR counts only as reference material (as specified by whoever commissioned this guide)
- Personal use, not submitting packages to any repo → not strict about clean chroot (`devtools`) or every naming rule
- The vendor examples (JetBrains, Google Chrome, LM Studio, Spotify, GNU Hello) were chosen because they really ship files of that kind per the checked URLs; this is not an endorsement of their suitability for the user, and build/run has not been tested

---

## 12. Implications for decisions (recommendations)

1. Make `~/pkgbuilds/` a git repo for your own PKGBUILDs → every program from outside the repos goes through pacman, is easy to remove, and `pacman -Qm` is a complete list
2. Keep `base-devel pacman-contrib namcap` installed permanently — that alone covers tarball/.deb/.rpm/source, no need for debtap
3. Closed/proprietary GUI apps that update often (browser, chat, music): try Flathub first and check the Verified badge · if it's not there, package the .deb as a PKGBUILD
4. Keep distrobox as a fallback for software that only supports Ubuntu/Fedora — don't use it to run things you don't trust
5. Set a personal rule: no unowned files in `/usr` (check periodically with the orphan-files command in section 10)

---

## 13. Still unanswered + how to find out

| Topic | What was tried | How to find out |
|---|---|---|
| Full ArchWiki content (Creating packages, Arch package guidelines, CMake/Meson package guidelines, Podman rootless) | opening directly, `?action=raw`, `api.php` → all blocked by Anubis · only search snippets usable | open in a browser, or `sudo pacman -S arch-wiki-docs` (❓ not checked whether the package still exists) and read offline |
| The AUR page for `debtap` (version, maintainer status) | opened the AUR page and RPC API → Anubis | open `https://aur.archlinux.org/packages/debtap` in a browser |
| Whether rootless podman on Arch requires setting up `/etc/subuid`/`/etc/subgid` yourself | ArchWiki Podman couldn't be opened | try: `grep "^$USER:" /etc/subuid` → if missing, `distrobox create` will error about user namespaces; fix per `man podman` / ArchWiki Podman |
| Where `rpmkeys --import` stores keys on Arch, and whether it needs root | not checked | read `man rpmkeys` (ships with `rpm-tools`) or experiment with `--dbpath ~/.rpmdb` |
| Whether AppImages using the newer runtime still need `fuse2` | the AppImage docs page that was opened mentions `fuse2` for Arch | test: run an AppImage without `fuse2` installed — if it errors with `libfuse.so.2`, it's needed |
| Fingerprint of the GNU Hello 2.12.3 signer | the files weren't downloaded to check | run `gpg --verify` per section 10 and compare against `gnu-keyring.gpg` |
| Internal layout of the JetBrains tarball / Chrome .deb / LM Studio's desktop file name | not downloaded | `bsdtar -tf <file>` before writing `package()` |
| GNU Coding Standards DESTDIR page | got HTTP 429 twice | open https://www.gnu.org/prep/standards/html_node/DESTDIR.html yourself (this guide cites CMake/Meson instead) |

---

## 14. Oddities found

- wiki.archlinux.org, gitlab.archlinux.org and aur.archlinux.org returned the Anubis v1.28.2 "Access Denied" page (error code `9e4edb5b6b850c41`) to automated page-fetching tools, while archlinux.org/packages and man.archlinux.org opened normally
- `makepkg.conf(5)` gives the `PKGEXT` default as `.pkg.tar.gz`, which is the compiled-in value — files actually built may have a different extension depending on what `/etc/makepkg.conf` sets (hence this guide uses `*.pkg.tar.*`)
- Spotify on Flathub is **Unverified / community-provided**, even though the app page shows Spotify as the developer
- AppImageLauncher: the latest release is a **beta** (v3.0.0-beta-3, 2025-10-28), and the README says `appimagelauncher-git` is "possibly broken"
- No hidden instruction text was found in the web pages opened

---

## 15. How to update each method

> Added 2026-11-06 at the user's request · ⚠️ this section was written by the main session from the man pages / documents cited in other sections of this file plus the author's own knowledge; it **has not been run/tested on a real Arch system**, and no web search was done this time — uncertain items are labeled ❓; check with `<command> --help` / the man page before use

**Key principle:** only the official repos (+ Flatpak, distrobox) have a "central update mechanism" — for every other method **you are the maintainer** and must find out about new versions yourself. The more methods you use, the more places you have to watch → another reason the decision tree in section 1 prefers the options at the top

### 15.1 Official repo (pacman)

```bash
checkupdates                 # see what would be updated without touching the system sync db (pacman-contrib) — safer than pacman -Sy
sudo pacman -Syu             # full system update — never -Sy followed by -S <pkg> (partial upgrade, section 1)
pacdiff                      # handle .pacnew / .pacsave files left over after updates (pacman-contrib)
paccache -r                  # clean the cache, keeping the 3 most recent versions (pacman-contrib) · paccache.timer does this automatically
```

- Before a big `-Syu`: read [archlinux.org/news](https://archlinux.org/news/) — sometimes manual intervention is needed
- Downgrade: `sudo pacman -U /var/cache/pacman/pkg/<pkg>-<oldver>-*.pkg.tar.zst` (if it's still in the cache)

### 15.2 Self-packaged PKGBUILDs (tarball / .deb / .rpm / source — 6a–6c)

Not updated by `pacman -Syu`; you do it yourself:

```bash
cd ~/pkgbuilds/<name>
$EDITOR PKGBUILD          # pkgver=<new> · pkgrel=1  (if only the packaging changed: pkgrel +1)
updpkgsums                # new checksums
makepkg -si               # pacman sees a higher version → upgrade
git commit -am "<name> <ver>"   # if you keep ~/pkgbuilds in git
```

**How to know there's a new version:**
- `pacman -Qm` = list of every package you maintain yourself (check regularly)
- Follow upstream releases: GitHub "Watch → Releases" / the releases page RSS feed (`https://github.com/<owner>/<repo>/releases.atom`)
- `nvchecker` — a tool that checks upstream versions automatically from a single config file ❓ not yet checked which official repo it's in (`pacman -Si nvchecker`)
- For a .deb whose URL is `current` (e.g. Chrome in 6b): `makepkg` fails the checksum when the vendor releases a new version = signal to update · see the version inside the downloaded .deb:
  ```bash
  bsdtar -xOf chrome-*.deb 'control.tar.*' | bsdtar -xOf - ./control | grep '^Version'
  ```

**Rebuild needed even if upstream hasn't released** — when `pacman -Syu` updates a library your package links against with an soname change (symptom: `error while loading shared libraries: libX.so.N`) or the major Python version changes (packages that install files into `/usr/lib/python3.X/`) → `pkgrel` +1, then `makepkg -si` · vendor binaries (6a/6b) are usually unaffected because they bundle their own libraries, but builds from source (6c) are often affected

### 15.3 Flatpak

```bash
flatpak remote-ls --updates          # see what has updates
flatpak update                       # update all apps + runtimes (for --user installs use flatpak update --user)
flatpak uninstall --unused           # remove old runtimes no app uses any more
```

- Pin to prevent updates: `flatpak mask <app-id>` (unpin: `flatpak mask --remove <app-id>`) ❓ check that your flatpak version has this command
- Downgrade: `flatpak remote-info --log flathub <app-id>` to see old commits → `sudo flatpak update --commit=<hash> <app-id>`
- Automatic updates: GNOME Software / KDE Discover can do it, or make your own systemd timer (example in 15.9)

### 15.4 AppImage

No central update mechanism — there are 3 options:
1. **The app updates itself** — many apps have a built-in update button/mechanism (the file must be in a user-writable folder, e.g. `~/Applications`)
2. **Gear Lever** (Flathub) — manages AppImages and lets you set a URL for update checks ❓ details of the update feature not checked this time
3. **By hand** — use versioned file names + a fixed-name symlink, so you don't have to edit the `.desktop` every time and can roll back:
   ```bash
   cd ~/Applications
   curl -fLO https://example.com/App-2.0.0-x86_64.AppImage   # + verify checksum/signature (section 10)
   chmod +x App-2.0.0-x86_64.AppImage
   ln -sfn App-2.0.0-x86_64.AppImage App.AppImage            # .desktop always points at App.AppImage
   # once it works well, delete the old version · roll back: ln -sfn App-1.9.0-x86_64.AppImage App.AppImage
   ```
- `appimageupdatetool` does delta updates from the update information embedded in the AppImage (only for files where the vendor embedded it) ❓ not yet checked whether there's a package in the official repos

### 15.5 Manually installed binary tarball (`~/.local/opt` — 3A)

Same principle as AppImage: **versioned folder + fixed-name symlink** → switch versions with one command, and roll back

```bash
ver=2.0.0
mkdir -p ~/.local/opt/app-$ver
bsdtar -xf app-$ver.tar.gz -C ~/.local/opt/app-$ver --strip-components 1
ln -sfn ~/.local/opt/app-$ver ~/.local/opt/app     # ~/.local/bin/app and the .desktop point via ~/.local/opt/app
app --version                                      # test
rm -rf ~/.local/opt/app-1.9.0                      # delete the old version once you're confident
```

- If the app **updates itself** (e.g. JetBrains Toolbox): let it do so; no need for this method — this is why apps like this are recommended to live in `~/.local/opt` rather than `/opt` (section 3A)

### 15.6 Source installed to `/usr/local` + GNU Stow (3B)

Name the stow package after the version, then switch:

```bash
./configure --prefix=/usr/local && make
sudo make DESTDIR=/usr/local/stow/app-2.0.0 install
# DESTDIR nests the files as .../app-2.0.0/usr/local/... → move them up to match the stow layout (as in section 3B)
sudo sh -c 'cd /usr/local/stow/app-2.0.0 && mv usr/local/* . && rm -r usr'
cd /usr/local/stow
sudo stow -D app-1.9.0          # remove the old version's symlinks
sudo stow app-2.0.0             # put in the new one
# roll back: sudo stow -D app-2.0.0 && sudo stow app-1.9.0
```

- Needs a rebuild when a system library changes soname, just like 15.2 — and nobody will warn you (pacman doesn't know these files) → if you use it long-term, move to a PKGBUILD (6c)

### 15.7 distrobox (.deb / .rpm in a container)

```bash
distrobox upgrade --all                     # update packages in every container with that distro's package manager
distrobox upgrade ub                        # only the container named ub
# or do it yourself inside the container:
distrobox enter ub -- sh -c 'sudo apt update && sudo apt full-upgrade -y'
distrobox enter fed -- sudo dnf upgrade -y
```

- **A .deb installed with `apt install ./X.deb` only gets updates if the vendor adds an APT repo** (e.g. Chrome's postinst adds Google's repo) — otherwise you must download the new .deb and `sudo apt install ./X-new.deb` yourself · check: `distrobox enter ub -- ls /etc/apt/sources.list.d/`
- Apps exported with `distrobox-export` keep working after the update (the launcher points to the binary in the container)
- The container's base image isn't wholesale-upgraded by `upgrade` — if the distro in the container reaches end of life (e.g. an old Ubuntu LTS), create a new container from a new image (`podman pull`, `distrobox create`) and export again

### 15.8 Language package managers / others

| Method | See what's outdated | Update | Notes |
|---|---|---|---|
| pipx | `pipx list` | `pipx upgrade X` · `pipx upgrade-all` | after Arch's Python changes major version: `pipx reinstall-all` |
| cargo | `cargo install --list` | `cargo install --locked X` (reinstalling = upgrade if there's a new version) | `rustup update` updates the toolchain (if using rustup) · the `cargo-update` crate helps upgrade everything at once (third-party) |
| npm global | `npm outdated -g` | `npm update -g` or `npm i -g X@latest` | — |
| go install | — (no central list) | `go install mod/path@latest` | you have to remember the module path → note it in a file |
| Homebrew | `brew outdated` | `brew update && brew upgrade` | — |
| Nix (profile) | — | `nix profile upgrade --all` ❓ syntax changes between Nix versions — check `nix profile upgrade --help` | old style: `nix-channel --update && nix-env -u` |
| `.pkg.tar.zst` obtained elsewhere | — | find the new file → `sudo pacman -U ./X-new.pkg.tar.zst` | no update source; better to get the PKGBUILD and build it yourself instead |
| `install.sh` from the web | per vendor | usually re-run the script, or there's a `<tool> self-update` command | re-read the script every time, since its content can change |

### 15.9 Combining into a single routine

Example weekly update script (run it yourself, not automatically — Arch recommends watching the output when updating):

```bash
#!/usr/bin/env bash
# ~/.local/bin/update-all
set -euo pipefail

echo "== pacman =="
checkupdates || true                       # exit 2 = no updates
sudo pacman -Syu
command -v pacdiff >/dev/null && sudo DIFFPROG="${DIFFPROG:-vimdiff}" pacdiff || true

echo "== flatpak ==";   command -v flatpak   >/dev/null && flatpak update -y && flatpak uninstall --unused -y || true
echo "== distrobox =="; command -v distrobox >/dev/null && distrobox upgrade --all || true
echo "== pipx ==";      command -v pipx      >/dev/null && pipx upgrade-all || true

echo "== check versions yourself (PKGBUILD / manual installs) =="
pacman -Qm                                 # self-packaged packages
ls ~/.local/opt 2>/dev/null || true        # manually installed tarballs
ls /usr/local/stow 2>/dev/null || true     # source + stow
```

If you want Flatpak to update quietly by itself (without touching pacman), use a systemd user timer:

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/flatpak-update.service <<'EOF'
[Unit]
Description=Update user Flatpaks
[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update --user -y --noninteractive
EOF
cat > ~/.config/systemd/user/flatpak-update.timer <<'EOF'
[Unit]
Description=Weekly Flatpak update
[Timer]
OnCalendar=weekly
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload && systemctl --user enable --now flatpak-update.timer
```
(`--user` only works for apps installed with `flatpak install --user` · system-level apps need a system timer + root)

---

## 16. Cheat sheet

| File / source | Recommended method (no AUR) | Main commands | How to update (15.x) | How to remove |
|---|---|---|---|---|
| in the official repos | pacman | `sudo pacman -Syu <pkg>` · find a file: `sudo pacman -Fy; pacman -F <file>` | `sudo pacman -Syu` (15.1) | `sudo pacman -Rs <pkg>` |
| GUI app on Flathub | Flatpak | `flatpak install flathub <app-id>` | `flatpak update` (15.3) | `flatpak uninstall <app-id>; flatpak uninstall --unused` |
| `.AppImage` | run directly (+`fuse2`) or Gear Lever (Flathub) | `sudo pacman -S fuse2; chmod +x X.AppImage; ./X.AppImage` | in-app / Gear Lever / new file + `ln -sfn` (15.4) | `rm X.AppImage` + any desktop file you created |
| `.tar.*` binary | PKGBUILD (6a) → `/opt/<pkg>` + symlink `/usr/bin` | `updpkgsums && makepkg -si` | edit `pkgver` → `updpkgsums && makepkg -si` (15.2) | `sudo pacman -R <pkg>` |
| `.tar.*` binary (temporary) | by hand → `~/.local/opt` + `~/.local/bin` | `bsdtar -xf X.tar.gz -C ~/.local/opt/X --strip-components 1; ln -s ...` | new version folder + `ln -sfn` (15.5) | `rm -rf ~/.local/opt/X ~/.local/bin/X ~/.local/share/applications/X.desktop` |
| `.tar.*` source | PKGBUILD (6c) | `makepkg -si` (`./configure --prefix=/usr; make DESTDIR="$pkgdir" install`) | edit `pkgver` → `makepkg -si` · rebuild when a lib changes (15.2) | `sudo pacman -R <pkg>` |
| `.tar.*` source (temporary) | `/usr/local` + Stow | `./configure --prefix=/usr/local; make; sudo make DESTDIR=/usr/local/stow/X install; sudo stow X` | build into `stow/X-<ver>` → `stow -D` old, `stow` new (15.6) | `sudo stow -D X; sudo rm -rf /usr/local/stow/X` |
| `.deb` | PKGBUILD (6b) | `source=(X.deb)` → `bsdtar -xf data.tar.* -C "$pkgdir"` → `makepkg -si` | edit `pkgver` → `updpkgsums && makepkg -si` (15.2) | `sudo pacman -R <pkg>` |
| `.deb` that won't run on Arch | distrobox (Ubuntu/Debian) | `distrobox create -i ubuntu:24.04 -n ub; distrobox enter ub; sudo apt install ./X.deb; distrobox-export --app X` | `distrobox upgrade ub` (if the vendor has an APT repo) or `apt install ./X-new.deb` (15.7) | `distrobox-export --app X --delete; distrobox rm ub` |
| `.rpm` | PKGBUILD (`bsdtar -xf X.rpm -C "$pkgdir"`) | `makepkg -si` · inspect: `bsdtar -tf X.rpm`, `rpm -qp --requires X.rpm` | edit `pkgver` → `updpkgsums && makepkg -si` (15.2) | `sudo pacman -R <pkg>` |
| `.rpm` that won't run on Arch | distrobox (Fedora) | `distrobox create -i registry.fedoraproject.org/fedora-toolbox:<ver> -n fed; sudo dnf install ./X.rpm` | `distrobox upgrade fed` or `dnf install ./X-new.rpm` (15.7) | `distrobox-export --app X --delete; distrobox rm fed` |
| `.pkg.tar.zst` obtained elsewhere | pacman | `sudo pacman -U ./X.pkg.tar.zst` | find the new file → `pacman -U` (15.8) | `sudo pacman -R <pkg>` |
| Python CLI | pipx | `pipx install X` | `pipx upgrade-all` (15.8) | `pipx uninstall X` |
| Rust CLI | cargo | `cargo install --locked X` | `cargo install --locked X` again (15.8) | `cargo uninstall X` |
| Node CLI | npm + prefix `~/.local` | `npm i -g X` | `npm update -g` (15.8) | `npm uninstall -g X` |
| Go CLI | go install | `go install mod/path@vX` | `go install mod/path@latest` (15.8) | `rm $(go env GOPATH)/bin/X` |
| `install.sh` script from the web | download → read → decide (can often be wrapped in a PKGBUILD instead) | `curl -fsSLo install.sh URL; less install.sh` | per vendor — re-read the script every time (15.8) | whatever the script did — note it down before running |

---

## 17. References

All checked on 2026-11-06 · (search snippet only) = seen only via search results; the full page couldn't be opened

**Arch Linux (official)**
- archlinux.org/packages: [base-devel](https://archlinux.org/packages/core/any/base-devel/) · [pacman-contrib files](https://archlinux.org/packages/extra/x86_64/pacman-contrib/files/) · [namcap](https://archlinux.org/packages/extra/any/namcap/) · [rpm search](https://archlinux.org/packages/?q=rpm) · [rpm-tools files](https://archlinux.org/packages/extra/x86_64/rpm-tools/files/) · [rpmextract](https://archlinux.org/packages/extra/any/rpmextract/) · [libarchive files](https://archlinux.org/packages/core/x86_64/libarchive/files/) · [binutils files](https://archlinux.org/packages/core/x86_64/binutils/files/) · [distrobox search](https://archlinux.org/packages/?q=distrobox) · [podman search](https://archlinux.org/packages/?q=podman) · [flatpak search](https://archlinux.org/packages/?q=flatpak) · [flatpak files](https://archlinux.org/packages/extra/x86_64/flatpak/files/) · [fuse2 search](https://archlinux.org/packages/?q=fuse2) · [debtap search (0 results)](https://archlinux.org/packages/?q=debtap) · [appimage search](https://archlinux.org/packages/?q=appimage) · [gearlever search (0 results)](https://archlinux.org/packages/?q=gearlever) · [stow](https://archlinux.org/packages/?q=stow) · [rust](https://archlinux.org/packages/extra/x86_64/rust/) · [nix](https://archlinux.org/packages/?q=nix) · [python-pipx](https://archlinux.org/packages/?q=pipx) · [obsidian](https://archlinux.org/packages/?q=obsidian)
- man pages: [pacman(8)](https://man.archlinux.org/man/pacman.8) · [makepkg(8)](https://man.archlinux.org/man/makepkg.8) · [PKGBUILD(5)](https://man.archlinux.org/man/PKGBUILD.5) · [makepkg.conf(5)](https://man.archlinux.org/man/makepkg.conf.5) · [ldd(1)](https://man.archlinux.org/man/ldd.1) · [libarchive-formats(5)](https://man.archlinux.org/man/libarchive-formats.5) · [pkgctl-repo-clone(1)](https://man.archlinux.org/man/pkgctl-repo-clone.1)
- ArchWiki (search snippet only): [pacman](https://wiki.archlinux.org/title/Pacman) · [System maintenance](https://wiki.archlinux.org/title/System_maintenance) · [Arch package guidelines](https://wiki.archlinux.org/title/Arch_package_guidelines) · [makepkg](https://wiki.archlinux.org/title/Makepkg) · [Flatpak](https://wiki.archlinux.org/title/Flatpak) · [Nix](https://wiki.archlinux.org/title/Nix) · [Talk:Nix](https://wiki.archlinux.org/title/Talk:Nix) · [Python](https://wiki.archlinux.org/title/Python) · [Node.js](https://wiki.archlinux.org/title/Nodejs) · [Desktop entries](https://wiki.archlinux.org/title/Desktop_entries)

**Upstream / vendor**
- Debian: [deb(5)](https://manpages.debian.org/unstable/dpkg-dev/deb.5.en.html) · [deb-control(5)](https://manpages.debian.org/unstable/dpkg-dev/deb-control.5.en.html)
- [libarchive README](https://raw.githubusercontent.com/libarchive/libarchive/master/README.md) · [CMake DESTDIR](https://cmake.org/cmake/help/latest/envvar/DESTDIR.html) · [Meson Installing](https://mesonbuild.com/Installing.html) · [GNU Stow manual](https://www.gnu.org/software/stow/manual/stow.html)
- distrobox: [README](https://raw.githubusercontent.com/89luca89/distrobox/main/docs/README.md) · [distrobox-create](https://raw.githubusercontent.com/89luca89/distrobox/main/docs/usage/distrobox-create.md) · [distrobox-export](https://raw.githubusercontent.com/89luca89/distrobox/main/docs/usage/distrobox-export.md)
- Flatpak/Flathub: [Using Flatpak](https://docs.flatpak.org/en/latest/using-flatpak.html) · [Flathub setup Arch](https://flathub.org/setup/Arch) · [Gear Lever](https://flathub.org/apps/it.mijorus.gearlever) · [Spotify](https://flathub.org/apps/com.spotify.Client)
- AppImage: [FUSE troubleshooting](https://docs.appimage.org/user-guide/troubleshooting/fuse.html) · [AppImageLauncher README](https://github.com/TheAssassin/AppImageLauncher) · [AppImageLauncher latest release (API)](https://api.github.com/repos/TheAssassin/AppImageLauncher/releases/latest)
- Languages/other: [cargo install](https://doc.rust-lang.org/cargo/commands/cargo-install.html) · [go install](https://pkg.go.dev/cmd/go#hdr-Compile_and_install_packages_and_dependencies) · [pipx configure paths](https://pipx.pypa.io/latest/how-to/configure-paths/) · [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux) · [brew.sh](https://brew.sh/)
- Vendor examples: [JetBrains Toolbox releases API](https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release) · [GNU Hello](https://ftp.gnu.org/gnu/hello/) · [GNU keyring dir](https://ftp.gnu.org/gnu/) · [Google Linux repositories](https://www.google.com/linuxrepositories/) · [LM Studio download](https://lmstudio.ai/download?os=linux) · [debtap upstream](https://github.com/helixarch/debtap)
