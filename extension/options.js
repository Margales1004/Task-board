const $ = (id) => document.getElementById(id);

function setStatus(msg, ok) {
  const el = $("status");
  el.textContent = msg;
  el.style.color = ok === false ? "#c0392b" : ok ? "#2e7d32" : "#68788a";
}

// Load saved values.
chrome.storage.sync.get(["dbUrl", "code"], ({ dbUrl, code }) => {
  if (dbUrl) $("dbUrl").value = dbUrl;
  if (code) $("code").value = code;
});

function readValues() {
  const dbUrl = $("dbUrl").value.trim().replace(/\/+$/, "");
  const code = $("code").value.trim();
  return { dbUrl, code };
}

$("save").addEventListener("click", () => {
  const { dbUrl, code } = readValues();
  if (!dbUrl || !code) {
    setStatus("Please fill in both the database URL and the code.", false);
    return;
  }
  chrome.storage.sync.set({ dbUrl, code }, () => setStatus("Saved ✓", true));
});

$("test").addEventListener("click", async () => {
  const { dbUrl, code } = readValues();
  if (!dbUrl || !code) {
    setStatus("Please fill in both the database URL and the code.", false);
    return;
  }
  chrome.storage.sync.set({ dbUrl, code });
  setStatus("Sending…");
  try {
    const url = `${dbUrl}/inbox/${encodeURIComponent(code)}.json`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: "Test from Chrome ✓",
        note: "Sent from the extension options",
        ts: Date.now(),
      }),
    });
    if (!res.ok) throw new Error("HTTP " + res.status);
    setStatus("Test task sent — check your Inbox in the app.", true);
  } catch (e) {
    setStatus("Failed: " + (e && e.message ? e.message : e), false);
  }
});
