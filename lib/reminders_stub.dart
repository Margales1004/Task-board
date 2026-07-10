// No-op implementation used on non-web targets (and in tests). The bridge is
// only meaningful inside the native WebView shell, which the web build targets.
bool bridgeAvailable() => false;
void requestPermission() {}
void cancelAll() {}
void cancel(int id) {}
void schedule(int id, String title, String body, int epochMs) {}
