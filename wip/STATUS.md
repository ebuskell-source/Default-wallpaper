# TLA BootPaper 5.5.5 (work in progress, 2026-10-21)
Sevilen's suggestions: greeting on/off switch, slower scrolling, a greeting style per theme, a nicer settings app.

Done (tested on a real macOS 26 Mac in GitHub Actions):
- Mac: new tla-player (player/player.c, built with zig; Intel + Apple silicon) draws each theme's greeting.
- Mac: Greeting on/off setting (common.zsh, settings.zsh, guard.zsh), styles table WV_GREETING_STYLES, gated
  to Experimental (WV_SINCE greeting-styles/greeting-switch 5.5.5); release 5.5.5, channels experimental 5.5.5.
- Mac: settings-app.js new look (cards, switches, "When to play it" menu, greeting switch). Not yet tested on a Mac.
- Windows: common.ps1 (switch + styles), greeting.ps1 (themed greeting engine), play-video.ps1 uses it
  (falls back to the classic greeting), install-video.ps1 copies greeting.ps1, $Version 36. Not yet tested.

Left to do:
1. Mac settings app: check the CI pictures (branch ci/results-mac-app), fix anything off.
2. Windows settings.ps1: greeting switch, smooth/slower scrolling (PreviewMouseWheel, proportional to Delta),
   new look. Test on a windows-latest runner.
3. Linux (tla-bootpaper.py): Greeting setting + switch in the app, styles (mpv Lua overlay), new look.
4. Release notes, build pkg / intunewin (detect-video-v36.ps1) / Setup exe / Linux tarball, publish
   (channels.json experimental 5.5.5), upload to Intune. Then delete the ci/* branches.
