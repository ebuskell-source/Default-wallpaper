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
    sendResponse({ sites, base: chrome.runtime.getURL('') });   // (base: for the sites' icons, _favicon/)
  });
  return true;   // (answers asynchronously)
});
