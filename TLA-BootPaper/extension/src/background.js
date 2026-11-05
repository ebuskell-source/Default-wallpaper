// TLA New Tab (part of TLA BootPaper 5.4). The TLA new tab page is an ordinary web page, so it can't see the browser's
// most-visited sites. This extension hands them to that page only (externally_connectable in the manifest): the title
// and address of up to 12 sites, the same tiles Chrome and Edge show on their own new tab page. Nothing is stored or
// sent anywhere else. (The page also shows each site's icon from the browser's own cache: _favicon/.)
const PAGE = 'https://ebuskell-source.github.io/Default-wallpaper/TLA-BootPaper/newtab/';

// 1.1: which background is on their desktop, from TLA BootPaper 6.3.5 or newer (its native messaging host; on
// computers without it, no answer and the page shows today's picture).
const HOST = 'ca.schoolathome.bootpaper';

chrome.runtime.onMessageExternal.addListener((message, sender, sendResponse) => {
  if (!message || !String(sender.url || '').startsWith(PAGE)) return false;
  if (message.type === 'background') {
    try {
      chrome.runtime.sendNativeMessage(HOST, { type: 'background' }, reply => {
        void chrome.runtime.lastError;   // (TLA BootPaper not installed, or older)
        const ok = reply && typeof reply.id === 'string' && /^[a-z0-9-]{1,40}$/.test(reply.id);
        sendResponse(ok ? { id: reply.id, look: reply.look === 'dark' || reply.look === 'light' ? reply.look : '' } : null);
      });
    } catch (e) { sendResponse(null); }
    return true;
  }
  if (message.type !== 'topSites') return false;
  chrome.topSites.get(list => {
    const sites = (list || [])
      .filter(s => s && /^https?:\/\//i.test(String(s.url)))
      .slice(0, 12)
      .map(s => ({ title: String(s.title || '').slice(0, 80), url: String(s.url) }));
    // 1.2: and their favourites: the sites on the bookmarks bar (Edge: favourites bar), not the folders on it
    const done = favourites => sendResponse({ sites, favourites, base: chrome.runtime.getURL('') });   // (base: for icons, _favicon/)
    // 1.3: every bookmarks bar, not only id '1': since 2025 Chrome keeps a signed-in person's synced bookmarks on a
    // bar of their own (folderType 'bookmarks-bar'), next to the computer's local one.
    try {
      chrome.bookmarks.getTree(tree => {
        void chrome.runtime.lastError;
        const bars = [], seen = new Set(), out = [];
        for (const root of tree || []) for (const n of root.children || []) {
          if (n.folderType === 'bookmarks-bar' || (n.folderType === undefined && n.id === '1')) bars.push(n);
        }
        for (const bar of bars) for (const b of bar.children || []) {
          if (!b.url || !/^https?:\/\//i.test(b.url) || seen.has(b.url)) continue;
          seen.add(b.url); out.push({ title: String(b.title || '').slice(0, 80), url: String(b.url) });
        }
        done(out.slice(0, 60));   // (1.4: up to 60; the page shows 9 and "All")
      });
    } catch (e) { done([]); }
  });
  return true;   // (answers asynchronously)
});
