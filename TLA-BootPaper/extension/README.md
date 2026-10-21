# TLA New Tab (browser extension)

Gives the TLA new tab page (`../newtab/`) the browser's most-visited sites and their icons, which an ordinary web
page can't read. It answers only that page (`externally_connectable`), and nothing leaves the browser.

- Extension ID: `bemjdlnfdfdgnkimadgogaadgdfnipam`
- Installed by policy in Chrome and Edge (ExtensionInstallForcelist):
  `bemjdlnfdfdgnkimadgogaadgdfnipam;https://ebuskell-source.github.io/Default-wallpaper/TLA-BootPaper/extension/updates.xml`
- `src/` is the extension; `tla-newtab.crx` is it packed and signed; `updates.xml` tells browsers the newest version.

To release a change: raise `version` in `src/manifest.json`, pack `src/` with the same private key
(`tla-newtab.pem`, kept by the TLA tech admin, not in this repository; a different key gives a different ID), and
update `version` in `updates.xml`.
