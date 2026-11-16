Anserin, modified by lukpednoi. The full list of sources and changes is in CREDITS.md.

Fastfetch's layout, ASCII art and images are imported from
https://github.com/mkhmtolzhas/mkhmtdots/tree/main/.config/fastfetch
and adapted to anserin's paths and logo settings.

Forked from Serpantinum: https://github.com/ilyamiro/serpantinum
Upstream commit: 86ed6452f77a7a6c7491a24459235405b50e5deb (2.2.7).
Original local import: 0a13376e4c09f5bb28a0dafcce19fba96f993896.
License: AGPL-3.0-or-later; see LICENSE.md.

The grouped widget picker/editor, Liquid Glass shader, shared Glass fills/backdrops,
wallpaper blend shader and app-theme templates are
adapted from Serpantinum's selected feature sources:
https://github.com/ilyamiro/serpantinum/tree/ef71ab802fcc87ca54de9bf29bbc1793dc05c56c
The new Material You SDDM theme retains its upstream metadata: Darkkal44, MIT.
Its day/night backgrounds (`bg.jpg`, `bg_dark.jpg`) come from the same upstream
Material You theme. It reuses the existing Google Sans font. Its Noto Sans fallback is
bundled with the Apache-2.0 license in config/sddm/themes/material-you-new/font/.

The audio processor is adapted from serpantinum-audio 0.4.0 (with its visualizer):
https://github.com/ilyamiro/serpantinum-audio/tree/cf81973482c0f1cb7ef144b17afb3714d2c4f96d
AGPL-3.0; source, license and local adaptations are in src/quickshell/native/audio/.
System info, brightness, monitors, keyboard locks and the night light can use the
optional serpantinum-core and serpantinum-gamma helpers when they are installed.
Google Sans Flex (src/assets/fonts/GoogleSansFlex.ttf, used by the Material clocks) comes
with upstream Serpantinum; Google LLC, SIL Open Font License 1.1 (https://openfontlicense.org).
Bar utility actions and lyric position guards follow the selected Serpantinum
feature sources above, adapted to Anserin's existing services and Music UI.

Lyrics recording-version matching is adapted from Sergi122's Serpantinum PR #524:
https://github.com/ilyamiro/serpantinum/pull/524 (AGPL-3.0-or-later).
Comparing provider results before selection follows the approach discussed in PR #503:
https://github.com/ilyamiro/serpantinum/pull/503.

Infinite Desktop v2's canvas, navigation and floating/tiled behavior is adapted from
https://github.com/sarodscommits/hyprland-infinitie-desktop-v2
at commit 38da6c85d729a310f34bba38df6689b87ee364d2.
Copyright (c) 2026 Sarods2D, MIT; see src/scripts/infinite-desktop-v2/LICENSE.
Mo's adaptation uses native Hyprland 0.56+ Lua input instead of raw input devices,
keeps existing shortcuts, scopes movement to one monitor/workspace and records recovery positions.
