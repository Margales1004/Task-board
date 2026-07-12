# My Boards — desktop quick capture (AutoHotkey)

A tiny global hotkey for Windows: select text in **any** app — Microsoft Teams
desktop, Outlook, a PDF, anywhere — press **Ctrl+Alt+Q**, and it's sent straight
to your My Boards **Inbox**. No browser needed.

It posts to the same free Firebase inbox the app already polls, so nothing new
to set up on the app side.

## Setup (one-time, ~3 min)

1. **Install AutoHotkey v2** from <https://www.autohotkey.com> (the big
   "Download" → v2).
2. Open `my-boards-capture.ahk` in Notepad and fill in the two lines at the top:
   - `DB_URL` — your Firebase database URL (same one in the app).
   - `CODE` — your pairing code from the app: **⚙ Settings → Browser capture**.
   Save the file.
3. **Double-click** `my-boards-capture.ahk` to run it. A green **H** icon appears
   in the system tray — that means it's listening.

## Use

- Select text anywhere → press **Ctrl+Alt+Q**.
- A small tray note confirms **"Added: …"**, and the task shows up in your Inbox
  within ~20 seconds (keep the app open on your phone so it pulls).

## Start automatically at login (optional)

1. Press **Win+R**, type `shell:startup`, press Enter.
2. Put a **shortcut** to `my-boards-capture.ahk` in that folder (right-drag →
   "Create shortcuts here").

Now it runs every time you log in.

## Notes

- Want a different hotkey? Change the `^!q::` line — `^` = Ctrl, `!` = Alt,
  `+` = Shift. E.g. `^+j::` is Ctrl+Shift+J.
- Nothing happens? Check that the tray icon is running, that the `CODE` and
  `DB_URL` match the app exactly, and that text was actually selected before the
  hotkey.
