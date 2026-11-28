# Credits

Where Anserin's parts come from, and what was changed.

[← Back to the README](README.md)

## License

Anserin is released under the **GNU AGPL v3.0 or later**, the same license as Serpantinum. Full text: [LICENSE.md](LICENSE.md).

In short (the license text is what counts):

- You can use, change and share Anserin.
- If you share it, changed or not, keep it under the AGPL, include the source code, and keep the license and this page.
- If you change it, say what you changed and when.
- There is no warranty.

Parts that came from other projects keep their own licenses, listed below.

## Sources

### Serpantinum

By **[ilyamiro](https://github.com/ilyamiro)** and contributors. AGPL-3.0.
https://github.com/ilyamiro/serpantinum

Anserin is a fork of Serpantinum **2.2.7** (commit
[`86ed6452`](https://github.com/ilyamiro/serpantinum/commit/86ed6452f77a7a6c7491a24459235405b50e5deb)), taken on
**16 October 2026**. Everything Anserin started with comes from there.

Some features from later Serpantinum versions were added afterwards:

- From [`ef71ab80`](https://github.com/ilyamiro/serpantinum/tree/ef71ab802fcc87ca54de9bf29bbc1793dc05c56c): the widget
  picker and editor, Liquid Glass, glass backdrops, the wallpaper blend shader, app themes, bar actions and lyric fixes.
- Music and visualizer from 2.2.14.
- Weather and battery art and alerts, the weather calendar, the Paint wallpaper transition, Light/Dark mode,
  wallpaper favorites, preset import/export, more widgets, GlassLens and SurfaceField.
- Lyrics matching from [PR #524](https://github.com/ilyamiro/serpantinum/pull/524) by Sergi122, and the provider
  comparison discussed in [PR #503](https://github.com/ilyamiro/serpantinum/pull/503).

Also from the Serpantinum project:

- The audio processor in `src/quickshell/native/audio/`, from
  [serpantinum-audio 0.4.0](https://github.com/ilyamiro/serpantinum-audio/tree/cf81973482c0f1cb7ef144b17afb3714d2c4f96d).
  AGPL-3.0. Its license and the changes made are in that folder.
- Fonts and the Material You SDDM theme that came with it:
  - Material You SDDM theme by Darkkal44, MIT.
  - Noto Sans, Apache-2.0.
  - Google Sans Flex, SIL Open Font License 1.1.

### Infinite Desktop

[hyprland-infinitie-desktop-v2](https://github.com/sarodscommits/hyprland-infinitie-desktop-v2) by Sarods2D,
commit `38da6c85`. MIT. License in `src/scripts/infinite-desktop-v2/`.

Changed to use Hyprland's Lua input instead of raw input devices, keep your shortcuts, and work per monitor.

### Fastfetch

The layout, ASCII art and images in `config/fastfetch/` come from
[mkhmtdots](https://github.com/mkhmtolzhas/mkhmtdots/tree/main/.config/fastfetch) by mkhmtolzhas, with paths changed
for Anserin.

### Wallpapers

The three photos in `src/assets/wallpapers/` are resized copies of:

- `anserin-teal-peaks.jpg`: [Daniel Leone](https://unsplash.com/photos/v7daTKlZzaw) on Unsplash (Unsplash License)
- `anserin-purple-lake.jpg`: [Ken Cheung](https://unsplash.com/photos/KonWFWUaAuk) on Unsplash (Unsplash License)
- `anserin-turquoise-lake.jpg`: [Rob Shumski](https://www.pexels.com/photo/1903702/) on Pexels (Pexels License)

### Logos in the README

The Codex and Claude icons come from [LobeHub Icons](https://github.com/lobehub/lobe-icons) (MIT). They are
trademarks of OpenAI and Anthropic, used here only to show which tools helped build Anserin.

## What's new in Anserin

Added since the fork:

- The Anserin interface: a frame around the screen, no bar, and its own settings.
- The left panel: User, System (with Bubble), Music, Weather, Network, Launcher, Timer, Wallpaper, Calculator and File.
- Control Center from the right edge.
- The corner revolver with quick actions.
- The duck, a desktop pet.
- The Simple lock screen.
- Terminal looks, Scrollable Tiling and shell prompt styles.
- The Bar editor and the Edge bar style.
- Location from nearby Wi-Fi, a YouTube widget and a file manager choice.
- The installer, uninstaller and `anserin -up`.

Changed from Serpantinum:

- Renamed to Anserin, with its own command, daemon and folders.
- Serpantinum's bar-based interface is removed (version 0.0.2). Anserin is the only interface.
- Serpantinum's updater and telemetry are off.
- Starts and stops inside your running Hyprland session.
- Many screens were restyled or reworked.
