# Credits, sources and changes

Anserin is a modified version of another program, so this page says plainly where its parts come from, what was
changed, and what was added. It is here to give credit where it's due, and because the licenses ask for it.

[← Back to the README](README.md)

---

## The license in short

Anserin as a whole is released under the **GNU Affero General Public License v3.0 or later** (AGPL-3.0-or-later),
the license of Serpantinum, which Anserin is built on. The full text is in [LICENSE.md](LICENSE.md).

What this means for you, in everyday words (the license text is what actually counts):

- You can use, study, change and share Anserin, including changed versions.
- If you share it, changed or not, you have to share it under the same AGPL license, with its source code, and keep
  the copyright and license notices, including this page.
- If you change it, say clearly that you changed it and roughly when, as this page does for Anserin.
- It comes with **no warranty**. See sections 15 and 16 of the license.

Some bundled parts come from other projects under their own licenses (MIT, Apache-2.0, SIL OFL). They are listed
below and keep those licenses. Their license files are shipped next to them.

---

## Where Anserin comes from

**Serpantinum**, by **ilyamiro** and its contributors
- Repository: https://github.com/ilyamiro/serpantinum
- License: AGPL-3.0
- Anserin was forked from Serpantinum **2.2.7** (upstream commit
  [`86ed6452`](https://github.com/ilyamiro/serpantinum/commit/86ed6452f77a7a6c7491a24459235405b50e5deb)) on
  **16 October 2026**.

Everything that was already in Serpantinum at that commit is their work. That includes the base of the shell: the
bar, the launcher, notifications, the settings window, the original lock screen and its animations, desktop
widgets, the wallpaper picker and Matugen theming, the media and system services, and the scripts behind them.
Anserin has changed many of these since; the original authors are not responsible for those changes.

### Taken from later Serpantinum versions

After the fork, some features were brought over from newer Serpantinum code and adapted to Anserin:

- From Serpantinum's selected feature sources at
  [`ef71ab80`](https://github.com/ilyamiro/serpantinum/tree/ef71ab802fcc87ca54de9bf29bbc1793dc05c56c):
  the grouped widget picker and editor, the Liquid Glass shader, the shared glass fills and backdrops, the wallpaper
  blend shader, app-theme templates, the bar's utility actions and the lyric position guards.
- The Music and visualizer pages from Serpantinum 2.2.14, split in Anserin into Lyrics, EQ and Audio pages.
- Weather and battery illustrations and alerts, the weather Dashboard calendar, the Paint wallpaper transition,
  Light/Dark color mode, more widgets (Text, Timer, round CPU/RAM/Disk/Temp/Battery), GlassLens and SurfaceField.
- Lyrics version matching, from Sergi122's pull request
  [#524](https://github.com/ilyamiro/serpantinum/pull/524) (AGPL-3.0-or-later), and comparing lyric providers before
  choosing one, following the approach discussed in [#503](https://github.com/ilyamiro/serpantinum/pull/503).

### Other projects used in Anserin

| Part | Comes from | License | Notes |
| --- | --- | --- | --- |
| Audio processor (`src/quickshell/native/audio/`) | [serpantinum-audio 0.4.0](https://github.com/ilyamiro/serpantinum-audio/tree/cf81973482c0f1cb7ef144b17afb3714d2c4f96d) by ilyamiro, with its visualizer | AGPL-3.0 | Source, license and Anserin's changes are in that folder. |
| Infinite Desktop (`src/scripts/infinite-desktop-v2/`) | [hyprland-infinitie-desktop-v2](https://github.com/sarodscommits/hyprland-infinitie-desktop-v2) by Sarods2D, commit `38da6c85` | MIT, © 2026 Sarods2D | Rewritten to use Hyprland 0.56+ Lua input instead of raw input devices; keeps your shortcuts and works per monitor. License in that folder. |
| Fastfetch layout, ASCII art and images (`config/fastfetch/`) | [mkhmtdots](https://github.com/mkhmtolzhas/mkhmtdots/tree/main/.config/fastfetch) by mkhmtolzhas | See the original repository | Paths and logo settings changed for Anserin. |
| SDDM themes Material You (`config/sddm/themes/`) | Material You SDDM theme by Darkkal44, including its day and night backgrounds | MIT | The theme metadata keeps the original author. The "New" theme is Anserin's change of it. |
| Noto Sans font in the SDDM theme | Google | Apache-2.0 | License in `config/sddm/themes/material-you-new/font/`. |
| Google Sans Flex (`src/assets/fonts/GoogleSansFlex.ttf`) | Google LLC, shipped with Serpantinum | SIL Open Font License 1.1 | https://openfontlicense.org |
| Optional helpers `serpantinum-core` and `serpantinum-gamma` | ilyamiro | See their repositories | Not bundled. Anserin uses them only if you have them installed. |

---

## What Anserin changed and added

Changed and new since the fork (16 October 2026 to now). Most new work is in the **Anserin interface**, which you can
switch to from the Default interface (the one that came from Serpantinum).

**New in Anserin**
- The Anserin interface: a frame around the screen, with no bar, and separate settings kept for each interface.
- The left panel: User, System (Graphs, Rings and **Bubble**), Music, Weather (with an animated weather scene),
  Network, Launcher, Timer, Wallpaper, Calculator and File pages, plus Edit panel and the Workspace-only capsule.
- Control Center from the right edge, with the Control board for all settings.
- The corner revolver in the bottom-left corner, with the desktop's quick actions.
- The duck: a desktop pet that walks, sleeps and dives.
- The Simple lock screen style, and the bullet from the corner revolver that locks the screen.
- Terminal and window appearance settings, Scrollable Tiling, shell prompt styles and Kitty integration.
- Quick Actions layout on all four edges, the Bar editor, the Edge bar style and bar alignment options.
- Location from nearby Wi-Fi (beaconDB) before falling back to IP, Keep Awake, preset import and export, wallpaper
  favourites, a file manager choice, and a YouTube picture-in-picture widget.
- The installer, uninstaller and `anserin -up`.

**Changed from Serpantinum**
- Renamed to Anserin, with its own command (`anserin`), daemon (`anserind`) and folders (`~/.config/anserin`, etc.).
- Serpantinum's updater and telemetry are turned off.
- Starting and stopping run inside your existing Hyprland session, and only Anserin's own processes are stopped.
- Many existing screens were restyled or reworked: the lock screen layouts, Settings, the music pages and widgets.

---

## Thanks

To **ilyamiro** for Serpantinum, and to everyone who contributed to it. Anserin wouldn't exist without your work.
