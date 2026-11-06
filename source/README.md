# TLA BootPaper source (snapshot 2026-11-06)

The current source of every platform, as built for the latest releases (Windows 7.5.0, Mac 7.4.0, Linux 7.4.0,
TLA New Tab 1.4). Pictures, videos and built installers are left out (they're in `main`, under TLA-BootPaper/).
Android is in `android/` on this branch. `wip/` is an older, partial copy from 2026-10-21; this folder replaces it.

**No signing keys are here, on purpose.** The Chrome extension key and the Android keystore are kept elsewhere
(see Hub issue #110, D2).

| Folder | What | Built with |
|---|---|---|
| windows/src, windows/installer | Windows scripts and the NSIS installer | `makensis -DVERSION= -DVIVERSION= -DSRC= -DOUT= installer/tla-bootpaper.nsi` |
| mac/payload, mac/scripts | Mac app, LaunchDaemons/Agents, postinstall | `tools/build-pkg.py <dir with payload/ and scripts/> <version> <out.pkg>` |
| mac/launcher, mac/ui, player | Mac launcher, TLA Care UI, video player | see each folder |
| linux | Linux package contents | `tar czf … --owner=0 --group=0 tla-bootpaper` |
| intune | Intune platform scripts (Chrome install, update now, BC time) | uploaded as-is |
| tools | Package, .intunewin and .crx builders | |
