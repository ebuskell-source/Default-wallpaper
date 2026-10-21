// TLA New Tab (part of TLA BootPaper 5.4). The TLA new tab page is an ordinary web page, so it can't see the browser's
// most-visited sites. This extension hands them to that page only (externally_connectable in the manifest): the title
// and address of up to 12 sites, the same tiles Chrome and Edge show on their own new tab page. Nothing is stored or
// sent anywhere else. (The page also shows each site's icon from the browser's own cache: _favicon/.)
const PAGE = 'https://ebuskell-source.github.io/Default-wallpaper/TLA-BootPaper/newtab/';

chrome.runtime.onMessageExternal.addListener((message, sender, sendResponse) => {
  if (!message || message.type !== 'topSites' || !String(sender.url || '').startsWith(PAGE)) return false;
  chrome.topSites.get(list => {
    const sites = (list || [])
      .filter(s => s && /^https?:\/\//i.test(String(s.url)))
      .slice(0, 12)
      .map(s => ({ title: String(s.title || '').slice(0, 80), url: String(s.url) }));
    sendResponse({ sites, base: chrome.runtime.getURL('') });   // (base: for the sites' icons, _favicon/)
  });
  return true;   // (answers asynchronously)
});
