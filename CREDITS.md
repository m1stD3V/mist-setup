# Credits and third-party notices

The code and configuration in this repository are licensed under the MIT
License (see [`LICENSE`](LICENSE)), except for the Discord bridge plugin noted
below. The bundled assets keep their own licenses and are **not** covered by
the MIT license. Keep this file and the `LICENSES/` directory with any copy or
redistribution of the repository.

## Fonts

### Tiny5

- File: `dotfiles/.config/quickshell/assets/Tiny5.ttf`
- Author: Stefan Schmidt (Stefan Schmidt Art)
- Source: <https://github.com/Gissio/font_Tiny5>
- Copyright: 2026 The Tiny5 Project Authors
- License: SIL Open Font License 1.1 — see
  [`LICENSES/OFL-1.1-Tiny5.txt`](LICENSES/OFL-1.1-Tiny5.txt)

### icons-in-terminal

- File: `dotfiles/.local/share/fonts/icons-in-terminal.ttf`
- Source: <https://github.com/sebastiencs/icons-in-terminal>
- Copyright: 2016 Dom Charlesworth; 2017 sebastien
- License: MIT — see
  [`LICENSES/MIT-icons-in-terminal.txt`](LICENSES/MIT-icons-in-terminal.txt)

The upstream project builds this font by merging glyphs from several icon
sets, including Font Awesome 4.7, Material Design Icons 3.0.1, Octicons 4.4.0,
Devicons 1.8.0, Weather Icons 2.0.10, Font Linux 0.9, Pomicons, Linea 1.0,
Font Mfizz 2.4.1, FiraCode 1.200 and Powerline Extra Symbols. See the upstream
README for the complete list and the individual projects' licenses.

### MesloLGS NF

Downloaded by `install.sh` from
[romkatv/powerlevel10k-media](https://github.com/romkatv/powerlevel10k-media);
not bundled in this repository. It is distributed under the SIL Open Font
License 1.1; see the upstream repository for the notice.

## Wallpapers

These images are bundled so a fresh install keeps the desktop's intended look.
They remain the property of their original authors and are not MIT-licensed.
The "Source / permission" column records what is known from the file metadata
or the image itself; replace "to confirm" with the real source and permission
before relying on it.

| File | Attribution | Source / permission |
|---|---|---|
| `ARCHCAT.png` | Arch Linux "A" logo with a cat illustration. Embedded XMP credits **Gibran Ortega Cruz** (Affinity 3.3.0). | Illustration permission to confirm; Arch Linux logo is a trademark of Arch Linux (see <https://archlinux.org/art/>). |
| `INSOMNYA.png` | ASCII-art angel with the word "INSOMNYA". Embedded XMP credits **Gabriel Silva** (Canva export). | Source and permission to confirm. |
| `RED.png` | Character illustration on red, with the marks **ARM_00X**, **TAC://JRK** and a circular **s-s-k** logo. Exported with Celsys Studio Tool. | Artist and permission to confirm. |
| `RETROARCH.png` | Arch Linux logo on a teal background. | Arch Linux logo is a trademark of Arch Linux (see <https://archlinux.org/art/>). |
| `THINK.png` | Lenovo ThinkPad "Think" logo. | Lenovo trademark and copyright (see <https://www.lenovo.com/us/en/legal/copytrade/>); permission to redistribute to confirm. |
| `Streetlight.jpg` | Black-and-white photograph of a streetlight at night. | Photographer and permission to confirm. |
| `ARTIST.jpg` | Anime illustration shown inside a Clip Studio Paint workspace. | Artist and permission to confirm. |
| `wallhaven-qrp5wr.png` | [Wallhaven #qrp5wr](https://wallhaven.cc/w/qrp5wr), uploaded by **guntherwaalderson2**; the page says "source not provided". Abstract dark purple pattern, 2560×1440. | [Wallhaven terms](https://wallhaven.cc/terms); original artist unknown. |
| `wallhaven-vp23o8.jpg` | Artwork by **Huhv.** (<https://www.pixiv.net/en/users/5458951>), [Wallhaven #vp23o8](https://wallhaven.cc/w/vp23o8), uploaded by **Artix**. 1920×1080. | [Wallhaven terms](https://wallhaven.cc/terms); verify permission with the artist. |

Wallhaven states that all images remain the property of their original owners.
A Wallhaven download is not by itself a license to redistribute the artwork.

## Audio

| File | Attribution | Source / permission |
|---|---|---|
| `dotfiles/.config/quickshell/assets/ring.wav` | Notification ring tone, 16-bit mono 22.05 kHz PCM. | Source and permission to confirm; replace with a self-made tone if unknown. |

## Discord bridge

The files under `dotfiles/.config/quickshell/discord-bridge/plugin/`
(`index.tsx`, `native.ts`) carry
`SPDX-License-Identifier: GPL-3.0-or-later` and are licensed under the GNU
General Public License, version 3 or later — see
[`LICENSES/GPL-3.0-or-later.txt`](LICENSES/GPL-3.0-or-later.txt). The rest of
the repository remains MIT-licensed.

`discord-bridge/install.sh` clones and builds
[Equicord](https://github.com/Equicord/Equicord) at install time; Equicord is
GPL-3.0. That checkout is not part of this repository.

`discord-bridge/auto-repair.sh`, `discord-bridge/setup-auto-repair.sh` and the
unit templates in `discord-bridge/systemd/` are part of this repository and stay
MIT-licensed; they only build and run the patched client.

## Generated themes

`dotfiles/.config/quickshell/scripts/sync-firefox-theme.py` and
`dotfiles/.config/quickshell/scripts/sync-openchamber-theme.py` generate theme
files for Firefox and OpenChamber from the current wallpaper. They write only to
the user's own Firefox profile and `~/.config/openchamber/themes`; neither
project's files are copied into this repository.

## Updating this file

If you add or replace an asset, add a row with its author, source URL and
license. If you are an author of one of the images above and want a different
credit or want it removed, open an issue or pull request.
