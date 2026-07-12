// No-op on non-web targets (and in tests).
bool available() => false;
void listen(void Function(String) onResult, void Function()? onDone) {}
void stop() {}
