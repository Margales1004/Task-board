const $ = (id) => document.getElementById(id);

// Prefill: use the captured selection if there was one; otherwise fall back to
// the clipboard (so "copy in Teams desktop → Alt+Shift+Q" lands the text here).
async function prefill() {
  const { pendingCapture } = await chrome.storage.session.get("pendingCapture");
  const p = pendingCapture || {};
  let name = p.name || "";
  const note = p.note || "";
  if (!name) {
    try {
      const clip = (await navigator.clipboard.readText()).trim();
      if (clip) name = clip;
    } catch (_) {
      // clipboard unavailable — leave the field empty for manual entry
    }
  }
  $("name").value = name;
  $("note").value = note;
  const el = $("name");
  el.focus();
  el.select();
}
prefill();

function setError(msg) {
  $("status").textContent = msg || "";
}

async function send() {
  const name = $("name").value.trim();
  const note = $("note").value.trim();
  if (!name) {
    setError("Please enter a task.");
    return;
  }
  const { dbUrl, code } = await chrome.storage.sync.get(["dbUrl", "code"]);
  if (!dbUrl || !code) {
    setError("Set the database URL and code in the extension options first.");
    chrome.runtime.openOptionsPage();
    return;
  }
  setError("");
  $("send").disabled = true;
  try {
    const base = String(dbUrl).replace(/\/+$/, "");
    const url = `${base}/inbox/${encodeURIComponent(code)}.json`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, note: note || null, ts: Date.now() }),
    });
    if (!res.ok) throw new Error("HTTP " + res.status);
    window.close();
  } catch (e) {
    $("send").disabled = false;
    setError("Failed: " + (e && e.message ? e.message : e));
  }
}

$("send").addEventListener("click", send);
$("cancel").addEventListener("click", () => window.close());
// Enter in the task field sends; Shift+Enter in the note makes a newline.
$("name").addEventListener("keydown", (e) => {
  if (e.key === "Enter") { e.preventDefault(); send(); }
});
