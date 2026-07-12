// My Boards — Quick Capture (MV3 service worker).
//
// Two ways to capture, both POST to a Firebase Realtime Database "inbox" keyed
// by a secret pairing code (the My Boards app polls it and imports the tasks):
//   • Instant  — right-click → "Add to My Boards", or the toolbar button.
//   • Edit     — right-click → "Add to My Boards (edit first…)", or the
//                keyboard shortcut (default Alt+Shift+Q). Opens a small popup
//                to tweak the title/note before sending.

const MENU_INSTANT = "add_instant";
const MENU_EDIT = "add_edit";

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: MENU_INSTANT,
      title: "Add to My Boards",
      contexts: ["selection", "page"],
    });
    chrome.contextMenus.create({
      id: MENU_EDIT,
      title: "Add to My Boards (edit first…)",
      contexts: ["selection", "page"],
    });
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
// Exposed on globalThis so the edit popup can reuse it.
async function sendTask(name, note) {
  const { dbUrl, code } = await getConfig();
  if (!dbUrl || !code) {
    notify("Open the extension options and paste your database URL and code first.");
    chrome.runtime.openOptionsPage();
    return false;
  }
  const base = String(dbUrl).replace(/\/+$/, "");
  const url = `${base}/inbox/${encodeURIComponent(code)}.json`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name, note: note || null, ts: Date.now() }),
  });
  if (!res.ok) throw new Error("HTTP " + res.status);
  return true;
}

async function instantSend(name, note) {
  try {
    const ok = await sendTask(name, note);
    if (ok) notify("Added ✓  " + name.slice(0, 60));
  } catch (e) {
    notify("Couldn't add task: " + (e && e.message ? e.message : e));
  }
}

// Stash the captured text and open the small edit window.
async function openEditPopup(prefill) {
  await chrome.storage.session.set({ pendingCapture: prefill });
  await chrome.windows.create({
    url: chrome.runtime.getURL("edit.html"),
    type: "popup",
    width: 440,
    height: 380,
  });
}

chrome.contextMenus.onClicked.addListener((info, tab) => {
  const title = (tab && tab.title) || "";
  const name = (info.selectionText || title || "Untitled").trim();
  const note = (tab && tab.url) || "";
  if (info.menuItemId === MENU_EDIT) {
    openEditPopup({ name, note });
  } else {
    instantSend(name, note || null);
  }
});

// Toolbar button: instant-capture the current page (title + url).
chrome.action.onClicked.addListener((tab) => {
  instantSend(((tab && tab.title) || "Untitled").trim(), (tab && tab.url) || null);
});

// Keyboard shortcut → grab the current selection and open the edit popup.
chrome.commands.onCommand.addListener(async (command) => {
  if (command !== "capture-edit") return;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  let selection = "";
  try {
    if (tab && tab.id != null) {
      const res = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: () => String(window.getSelection()),
      });
      selection = (res && res[0] && res[0].result) || "";
    }
  } catch (_) {
    // some pages (chrome://, web store) block injection — fall back to title
  }
  const name = (selection || (tab && tab.title) || "").trim();
  openEditPopup({ name, note: (tab && tab.url) || "" });
});
