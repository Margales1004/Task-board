#Requires AutoHotkey v2.0
#SingleInstance Force
;
; My Boards — desktop quick capture (AutoHotkey v2)
;
; Global hotkey Ctrl+Alt+Q: copies whatever text is selected in ANY app
; (Teams desktop, Outlook, a PDF, anything), and sends it straight to your
; My Boards Inbox — no browser needed.
;
; SETUP
;   1. Install AutoHotkey v2 from https://www.autohotkey.com
;   2. Fill in the two values below (same URL + code as in the app's
;      Settings -> Browser capture).
;   3. Double-click this file to run it (a green "H" appears in the tray).
;   4. To start it automatically at login: press Win+R, type  shell:startup ,
;      Enter, and drop a shortcut to this file in that folder.
;
; USE
;   Select text anywhere -> press Ctrl+Alt+Q -> a tray note confirms "Added".

; ===================== CONFIG — fill these in =====================
DB_URL := "https://task-board-ed24a-default-rtdb.europe-west1.firebasedatabase.app"
CODE   := "PASTE_YOUR_PAIRING_CODE_HERE"
; ==================================================================

^!q::CaptureSelection()   ; Ctrl+Alt+Q

CaptureSelection() {
    prev := ClipboardAll()          ; remember what was on the clipboard
    A_Clipboard := ""
    Send("^c")                       ; copy the current selection
    if !ClipWait(1) {
        A_Clipboard := prev
        TrayTip("Select some text first, then press Ctrl+Alt+Q.", "My Boards")
        return
    }
    text := Trim(A_Clipboard, " `t`r`n")
    A_Clipboard := prev              ; restore the original clipboard
    if (text = "") {
        TrayTip("Nothing to add.", "My Boards")
        return
    }
    SendTask(text)
}

SendTask(name) {
    global DB_URL, CODE
    if (CODE = "PASTE_YOUR_PAIRING_CODE_HERE" || CODE = "") {
        TrayTip("Open this script and set your pairing code first.", "My Boards")
        return
    }
    url := RTrim(DB_URL, "/") . "/inbox/" . CODE . ".json"
    body := '{"name":' . JsonStr(name) . ',"note":"From desktop"}'
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("POST", url, false)
        req.SetRequestHeader("Content-Type", "application/json")
        req.Send(body)
        if (req.Status = 200)
            TrayTip("Added: " . SubStr(name, 1, 50), "My Boards")
        else
            TrayTip("Failed (HTTP " . req.Status . ")", "My Boards")
    } catch as e {
        TrayTip("Error: " . e.Message, "My Boards")
    }
}

; Minimal JSON string encoder: wrap in quotes and escape special characters.
JsonStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", " ")
    return '"' . s . '"'
}
