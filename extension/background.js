// My Boards — Quick Capture (MV3 service worker).
//
// Right-click a selection (or use the toolbar button) → the captured task is
// POSTed to a Firebase Realtime Database "inbox" keyed by a secret pairing
// code. The My Boards app polls that inbox and imports the tasks. Pair the two
// by entering the same database URL + code in this extension's options.

const MENU_ID = "add_to_my_boards";

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: MENU_ID,
    title: 'Add to My Boards',
    contexts: ["selection", "page"],
  });
});

async function getConfig() {
  const { dbUrl, code } = await chrome.storage.sync.get(["dbUrl", "code"]);
  return { dbUrl, code };
}

function notify(message) {
  chrome.notifications.create({
    type: "basic",
    iconUrl: "icons/icon48.png",
    title: "My Boards",
    message,
  });
}

// POST one captured task to the cloud inbox. Firebase mints the push key.
async function send(name, note) {
  const { dbUrl, code } = await getConfig();
  if (!dbUrl || !code) {
    notify("Open the extension options and paste your database URL and code first.");
    chrome.runtime.openOptionsPage();
    return;
  }
  const base = String(dbUrl).replace(/\/+$/, "");
  const url = `${base}/inbox/${encodeURIComponent(code)}.json`;
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, note: note || null, ts: Date.now() }),
    });
    if (!res.ok) throw new Error("HTTP " + res.status);
    notify("Added ✓  " + name.slice(0, 60));
  } catch (e) {
    notify("Couldn't add task: " + (e && e.message ? e.message : e));
  }
}

chrome.contextMenus.onClicked.addListener((info, tab) => {
  const name = (info.selectionText || (tab && tab.title) || "Untitled").trim();
  const note = (tab && tab.url) || null;
  send(name, note);
});

// Toolbar button: capture the current page (title + url) with no selection.
chrome.action.onClicked.addListener((tab) => {
  const name = ((tab && tab.title) || "Untitled").trim();
  send(name, (tab && tab.url) || null);
});
