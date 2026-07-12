# My Boards — Quick Capture (Chrome extension)

Select text on any web page, right-click → **Add to My Boards**, and the task
appears in the **Inbox** board of your My Boards app — including on your phone.

It works by writing captured tasks to a tiny free **Firebase Realtime Database**
"inbox" that the app polls every ~20 seconds. The extension and the app are
paired by a **database URL** + a secret **code**.

---

## 1. Create the free Firebase inbox (one-time, ~5 min)

1. Go to <https://console.firebase.google.com> and **Add project** (any name,
   Analytics off).
2. In the left menu: **Build → Realtime Database → Create Database**. Pick a
   location, and start in **locked mode**.
3. Open the **Rules** tab, replace the rules with the following, and **Publish**:

   ```json
   {
     "rules": {
       "inbox": {
         "$code": {
           ".read": true,
           ".write": true
         }
       }
     }
   }
   ```

   This keeps everything outside `inbox` private, and gates the inbox behind
   your secret code. (Tradeoff: anyone who knows both the URL *and* the code
   could add/read items in your inbox — so keep the code private. Fine for a
   personal setup.)
4. Copy the database URL shown at the top of the Data tab — it looks like
   `https://your-project-default-rtdb.firebaseio.com`.

## 2. Get your pairing code from the app

In the My Boards app: **⚙ Settings → Browser capture**. Paste the database URL
there, copy the **pairing code** it shows, and tap **Save**.

## 3. Install the extension

1. Open `chrome://extensions` in Chrome.
2. Turn on **Developer mode** (top-right).
3. Click **Load unpacked** and select this `extension/` folder.
4. Click the extension's **Details → Extension options** (or the puzzle-piece
   menu → this extension → Options).
5. Paste the **same database URL** and **pairing code**, click **Save**, then
   **Send a test task** — it should appear in your app's Inbox within ~20s.

## Using it

Two ways to capture — pick whichever fits the moment:

- **Instant** — select text → right-click → **Add to My Boards** (or click the
  toolbar icon to grab the current page). Sends immediately: the selection is
  the task name, the page URL goes in the note.
- **Edit first** — right-click → **Add to My Boards (edit first…)**, or press
  the keyboard shortcut (**Alt+Shift+Q** by default). A small window opens
  prefilled with the selection so you can tweak the title/note before adding.

Change the shortcut anytime at `chrome://extensions/shortcuts`.

### Capturing from desktop apps (e.g. Microsoft Teams)

The extension can't see inside non-browser apps, but the edit popup reads your
clipboard, so it still takes two seconds:

1. In the app (e.g. Teams desktop), select the message and **copy** it (Ctrl+C).
2. Switch to Chrome (any tab) and press **Alt+Shift+Q**.
3. The popup opens with the copied text already filled in — edit if needed and
   press **Enter**.

## Notes

- The inbox only holds tasks briefly — the app deletes each one right after
  importing it.
- If nothing shows up: re-check that the URL and code match exactly in both the
  app and the extension options, and that the Realtime Database rules above were
  published.
