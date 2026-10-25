# ✨ Pixie SDDM

A clean, modern, and minimal SDDM theme inspired by Google Pixel UI and Material Design 3. Supports both the latest **Qt6** engine and legacy **Qt5** systems.

<div align="center">
  <img src="screenshots/lock_screen.png" width="45%" alt="Lock Screen" />
  <img src="screenshots/login_screen.png" width="45%" alt="Login Screen" />
</div>

<div align="center">
  <img src="screenshots/lock_screen_2.png" width="22%" />
  <img src="screenshots/login_screen_2.png" width="22%" />
  <img src="screenshots/lock_screen_3.png" width="22%" />
  <img src="screenshots/login_screen_3.png" width="22%" />
</div>

<div align="center">
  <img src="screenshots/lock_screen_4.png" width="22%" />
  <img src="screenshots/login_screen_4.png" width="22%" />
  <img src="screenshots/lock_screen_5.png" width="22%" />
  <img src="screenshots/login_screen_5.png" width="22%" />
</div>

## 🌟 Features

- **Pixel Aesthetic:** Clean typography and a unique two-tone stacked clock.
- **Material You Dynamic Colors:** Intelligent color extraction that samples your wallpaper for UI accents.
- **Desktop Wallpaper Sync:** Shares your *actual desktop wallpaper* with the login screen, so SDDM always matches your session.
- **Matugen Theming (optional):** Generates a full Material You palette from your wallpaper via [Matugen](https://github.com/InioX/matugen) — accent, card/background surfaces and text colors all follow it.
- **Next-Gen Blur:** High-performance Gaussian blur (Qt6) and custom shader blur (Qt5).
- **Universal Circle Avatar:** A bulletproof, anti-aliased circular profile mask that works on all systems.
- **Material Design 3:** Dark card UI with smooth interactions and responsive dropdowns.
- **Keyboard Navigation:** Full support for navigating menus with arrows and `Enter`.

---

## 🛠 1. Prerequisites (Essential)

Before installing, ensure you have the required modules for your system version to avoid a black screen:

<details open>
<summary><b>Qt6 (Default / Modern Distros)</b></summary>
Recommended for Fedora 40+, Arch Linux, CachyOS, NixOS.

```bash
# Arch:
sudo pacman -S qt6-declarative qt6-svg

# Fedora:
sudo dnf install qt6-qtdeclarative qt6-qtsvg

# Debian 13/Testing:
sudo apt install libqt6quick6 libqt6qml6 libqt6svg6 libqt6quickcontrols2-6
```
</details>

<details>
<summary><b>Qt5 (Legacy / Stable Distros)</b></summary>
Required for Ubuntu 22.04/24.04, Debian 12, Linux Mint.

```bash
# Ubuntu: sudo apt install qml-module-qtgraphicaleffects qml-module-qtquick-controls2
# Arch: sudo pacman -S qt5-graphicaleffects qt5-quickcontrols2
```
</details>

---

## 📦 2. Installation

Pixie SDDM automatically detects your system and installs the correct version.

| System Type | Engine | Recommended Branch |
| :--- | :--- | :--- |
| **Bleeding Edge** (Fedora, Arch, Nix) | **Qt6** | `main` (Default) |
| **Stable/LTS** (Ubuntu, Debian) | **Qt5** | `qt5` |

### Method A: Automatic Script (Recommended)
This script intelligently detects your Qt version and handles everything:

<div align="center">
  <img src="screenshots/install.gif" width="70%" alt="Automatic installation demo" />
</div>

```bash
git clone https://github.com/xCaptaiN09/pixie-sddm.git
cd pixie-sddm
sudo ./install.sh
```

### Method B: Arch Linux (AUR)
The AUR package automatically tracks the latest modern version:
```bash
yay -S pixie-sddm-git
```

### Method C: NixOS (Flake)
The most modern and flexible way to install.

1. In your **`flake.nix`**, add the input and pass it to your modules:
```nix
{
  inputs.pixie-sddm.url = "github:xCaptaiN09/pixie-sddm";

  outputs = { self, nixpkgs, pixie-sddm, ... }@inputs: {
    nixosConfigurations.YOUR_HOSTNAME = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; }; # Passes inputs to all modules
      modules = [ ./configuration.nix ];
    };
  };
}
```

2. In your **`configuration.nix`**, configure SDDM and apply the theme:
```nix
{ pkgs, inputs, ... }: {
  services.displayManager.sddm = {
    enable = true;
    theme = "pixie";
    wayland.enable = true; # Optional: for Wayland sessions

    # Crucial for Qt6: Use the KDE/Qt6 build of SDDM to fix missing
    # cursors and module errors.
    package = pkgs.kdePackages.sddm;

    # Required dependencies for Qt6 themes
    extraPackages = [
      pkgs.kdePackages.qtsvg
      pkgs.kdePackages.qtdeclarative
      pkgs.kdePackages.qt5compat
    ];
  };

  environment.systemPackages = [
    # Install and customize the theme. All fields are optional and will
    # fall back to theme defaults if not set.
    (inputs.pixie-sddm.packages.${pkgs.stdenv.hostPlatform.system}.pixie-sddm.override {
      background = ./my-background.jpg; # Nix path or absolute path
      avatar = ./my-avatar.jpg;         # Nix path or absolute path
      accentColor = "#3F5F91";          # Hex color code
      autoColor = true;                 # true/false
      backgroundColor = "#1A1C1E";      # Hex color code
      textColor = "#E2E2E6";            # Hex color code
      fontFamily = "JetBrains Mono";    # Font family name (must be installed system-wide)
    })
  ];
}
```

### Method D: NixOS (Legacy / Non-Flake)
Add the following to your `configuration.nix`. (Change `rev = "main"` to
`rev = "qt5"` for legacy systems).

> [!NOTE]
> For Qt6: If you are using the `main` (Qt6) branch, you **must** use
> `pkgs.kdePackages.sddm` to ensure the Qt6 platform plugins load
> correctly. Without this, your mouse cursor may not appear.

```nix
{ pkgs, ... }: {
  services.displayManager.sddm = {
    enable = true;
    theme = "pixie";
    # Crucial for Qt6: Use the KDE/Qt6 build of SDDM to fix missing cursors and module errors
    package = pkgs.kdePackages.sddm;

    # Fix for NixOS explicitly requiring a cursor theme
    settings = {
      Theme = {
        CursorTheme = "breeze_cursors"; # Change this if you use a different cursor theme (e.g., Adwaita)
      };
    };
  };

  environment.systemPackages = [
    (pkgs.stdenv.mkDerivation {
      name = "pixie-sddm";
      src = pkgs.fetchFromGitHub {
        owner = "xCaptaiN09";
        repo = "pixie-sddm";
        rev = "main";
        hash = pkgs.lib.fakeHash;
      };
      installPhase = "
        mkdir -p $out/share/sddm/themes/pixie
        cp -r * $out/share/sddm/themes/pixie/
      ";
    })
    # Correct Qt6 dependencies for NixOS
    pkgs.kdePackages.qtdeclarative
    pkgs.kdePackages.qtsvg
    pkgs.kdePackages.qt5compat # Included for wider QML component compatibility
  ];
}
```

### Method E: Manual
1. Copy the folder to SDDM themes directory:
   `sudo cp -r pixie-sddm /usr/share/sddm/themes/pixie`
2. Set the theme in `/etc/sddm.conf`:
   ```ini
   [Theme]
   Current=pixie
   ```

---

## 🛠 Configuration & Testing

### Preview Without Logging Out
Run this command to preview the theme safely:
```bash
# For Qt6 (Modern):
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/pixie

# For Qt5 (Legacy):
sddm-greeter --test-mode --theme /usr/share/sddm/themes/pixie
```

---

## 🔄 Desktop Wallpaper Sync & Matugen Theming

Pixie runs inside SDDM, a separate process that **cannot read private files in
your home directory**. This optional feature bridges your desktop session and
the greeter:

1. `scripts/update-wallpaper.sh` takes (or detects) your current desktop wallpaper.
2. It copies it to a world-readable shared directory, by default `/var/lib/sddm/pixie/`.
3. If [Matugen](https://github.com/InioX/matugen) is installed, it generates a Material You palette from that wallpaper.
4. It updates the installed theme's `theme.conf` (`wallpaper=`, `matugen*=` keys).
5. The next time the greeter is shown, it uses the synced wallpaper and palette.

The bundled palette/extraction behavior is your fallback at every step: if
Matugen is missing, fails, or a wallpaper file disappears, the theme silently
falls back to `autoColor`/`accentColor`/`background` — never a black screen.

### Optional Dependencies

| Tool | Purpose | Install |
| :--- | :--- | :--- |
| `matugen` (>= 1.0; tested with 4.2) | Material You color generation | `pacman -S matugen` / `cargo install matugen` |

The sync itself only needs standard tools every distro has (`file`, `sed`, `sha256sum`, `cp`). No new Qt modules are required; everything else ships with the theme.

### Enable (Quick Start)

```bash
# From the repo (Qt6/Qt5 agnostic; detection runs as your user, writes use sudo once):
sudo -E ./scripts/update-wallpaper.sh /path/to/your/wallpaper.jpg

# or let it detect the current desktop wallpaper (GNOME/Cinnamon/MATE/Plasma,
# Hyprland+hyprpaper, swww, quickshell state files, nitrogen, feh, Xfce):
sudo -E ./scripts/update-wallpaper.sh
```

When installed, the script also lives in the theme directory:

```bash
sudo -E /usr/share/sddm/themes/pixie/scripts/update-wallpaper.sh
```

Each wallpaper change just means re-running this command; nothing is polled,
and no display-manager service is restarted. The SDDM greeter re-reads
`theme.conf` on every start, so the colors apply on the *next* login screen,
never while your session is running.

### Configuration Keys (theme.conf)

| Key | Default | Meaning |
| :--- | :--- | :--- |
| `wallpaper` | *(empty)* | Synced wallpaper path. Empty = use `background`. |
| `matugen` | `false` | When `true`, the `matugenAccent/matugenBackground/matugenText` keys take priority over `accentColor/backgroundColor/textColor`. |
| `matugenAccent` / `matugenBackground` / `matugenText` | *(same as static colors)* | Generated by Matugen; read-only for you. |

Palette priority inside the greeter: `matugen*` > `autoColor` (runtime
extraction) > static `accentColor`.

### CLI options

```
-m, --mode <dark|light>   Matugen scheme mode (default dark).
-f, --force               Regenerate even if the wallpaper is unchanged.
-d, --disable             Undo the sync (clears "wallpaper", turns Matugen off).
-t, --theme-dir <dir>     Theme install dir (default /usr/share/sddm/themes/pixie).
    --assets-dir <dir>    Shared dir (default /var/lib/sddm/pixie).
-n, --dry-run             Check what would happen without writing anything.
Environment: PIXIE_WALLPAPER, PIXIE_THEME_DIR, PIXIE_ASSETS_DIR, PIXIE_MODE,
PIXIE_SCHEME, PIXIE_SOURCE_COLOR_INDEX, PIXIE_DISABLE_MATUGEN, PIXIE_DEBUG.
```

### Automatic Sync With Quickshell (recommended)

If your wallpaper is managed by Quickshell (e.g. end-4 style shells), Matugen
already rewrites `~/.local/state/quickshell/user/generated/wallpaper/path.txt`
on every change. A systemd **path unit** reacts to that file:

```bash
sudo ./scripts/system/bootstrap.sh          # one-time, system side (see below)
install -Dm644 scripts/system/pixie-sddm-sync.path    ~/.config/systemd/user/pixie-sddm-sync.path
install -Dm644 scripts/system/pixie-sddm-sync.service ~/.config/systemd/user/pixie-sddm-sync.service
systemctl --user daemon-reload && systemctl --user enable --now pixie-sddm-sync.path
```

`bootstrap.sh` backs up the theme, adds the missing `wallpaper=`/`matugen=`
keys to the installed `theme.conf`, creates `/var/lib/sddm/pixie`, installs the
fixed `/usr/local/bin/pixie-sddm-sync` helper, a passwordless `sudoers` entry
for **that one helper only**, and runs the first real sync. The hook then:

- fires only when the state file actually changes (event-driven, no polling),
- skips regeneration when the wallpaper content is unchanged (hash check),
- never touches your Quickshell config or desktop theming.

Disable it with `systemctl --user disable --now pixie-sddm-sync.path` and
remove `/etc/sudoers.d/pixie-sddm-sync` to drop the sudoers entry.

### Integrating With Your Wallpaper Changer

Honest note: there is no universal "current wallpaper" API on Linux, and each
compositor exposes it differently (if at all). The script therefore tries a
best-effort detection chain — and any tool can simply call the script after
changing the wallpaper:

```bash
# Example: at the end of a Hyprland wallpaper script
~/.local/bin/waypaper --change "$NEW_WALL" && \
  sudo -E /usr/share/sddm/themes/pixie/scripts/update-wallpaper.sh "$NEW_WALL"
```

<details>
<summary><b>GNOME / Cinnamon / MATE (event-driven example)</b></summary>

```bash
gsettings monitor org.gnome.desktop.background picture-uri 2>/dev/null | while read -r _; do
  sudo -E /usr/share/sddm/themes/pixie/scripts/update-wallpaper.sh &
done
```
(Run it in your autostart; it only acts when the wallpaper actually changes.)
</details>

<details>
<summary><b>Custom source (hook)</b></summary>

The detection chain first consults an executable user hook that prints a path:

```bash
~/.config/pixie-sddm/get-wallpaper.sh
#!/bin/sh
# e.g. whatever your ricer knows best:
cat ~/.local/state/my-rice/current-wallpaper
```
</details>

<details>
<summary><b>Fast paths (NixOS)</b></summary>

The theme's `theme.conf` lives in the read-only Nix store. Add the `wallpaper`/
palette keys via the flake override instead of the script:

```nix
(inputs.pixie-sddm.packages.${system}.pixie-sddm.override {
  wallpaper = "/var/lib/sddm/pixie/wallpaper.jpg"; # file set up yourself
  matugenAccent = "#88d0ed";
  matugenBackground = "#0f1416";
  matugenText = "#dee3e6";
  matugen = true;
})
```
The script can still refresh `/var/lib/sddm/pixie` (it accepts
`--theme-dir`/`--assets-dir`), but theme.conf is yours to manage declaratively.
</details>

### Permissions & Security

- `/var/lib/sddm/pixie` is `755`/`644` — world-readable but not writable.
- Nothing from `$HOME` is exposed except a **copy** of the wallpaper itself.
- `sudo -E` is only requested when a write would otherwise fail; detection
  always runs as your user. `install.sh` creates the shared dir as `root:root 755`.
- To avoid repeated sudo: `sudo install -d -o "$USER" -m 755 /var/lib/sddm/pixie`.
- Passwords/any auth data are never touched.

### Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| Wallpaper not detected | Pass the path explicitly (`update-wallpaper.sh "$WALL"`) or add a hook. |
| `Matugen failed` | Run with `PIXIE_DEBUG=1` to see the real error; check `matugen --version` (>= 1.0 supported, >= 4.0 recommended). |
| Greeter shows the default wallpaper | `theme.conf` lost its `wallpaper=` key (a reinstall reset it) — rerun the script, or the file vanished (theme falls back automatically). |
| Colors did not change | `matugen` is likely absent; the wallpaper still synced. Install matugen and rerun with `--force`. |
| Wallpaper unreadable by greeter | Check `/var/lib/sddm/pixie` and its parents are `a+rx`. |

### Rollback / Disable

```bash
sudo -E /usr/share/sddm/themes/pixie/scripts/update-wallpaper.sh --disable
# or hand-edit /usr/share/sddm/themes/pixie/theme.conf:
#   delete or empty the "wallpaper=" line and set matugen=false
```
The static `accentColor`/`backgroundColor`/`autoColor` behavior is exactly
what it was before this feature.

---

## 🎨 Customization

Edit `theme.conf` or replace assets in `assets/`:
- **Wallpaper:** Replace `assets/background.jpg`, *or* use the wallpaper sync above.
- **Avatar:** Replace `assets/avatar.jpg`.
- **Dynamic Colors:**
  - `autoColor=true` (Default): Automatically extracts a Material You accent color from your wallpaper.
  - `autoColor=false`: Disables extraction and strictly uses the `accentColor` you set in `theme.conf`.
  - `matugen=true` (after running the sync script): Uses the full Matugen-generated palette, taking priority over both.
- **Background Colors:** Change `backgroundColor` in `theme.conf`. The login card, input fields, and borders will automatically generate lighter variants to match.
- **Clock Format:** Set `use24HourClock=false` in `theme.conf` to switch to a 12-hour clock, or `use24HourClock=true` for 24-hour.

## 🤝 Credits

- **Author:** [xCaptaiN09](https://github.com/xCaptaiN09)
- **Design:** Inspired by Google Pixel and MD3.
- **Font:** Flex Rounded & Material Design Icons (included).

---
*Made with ❤️ for the Linux community.*
