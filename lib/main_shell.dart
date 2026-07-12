// APK "shell" entrypoint.
//
// The real app is built for the web and hosted on GitHub Pages. This tiny
// native app just wraps that hosted URL in a full-screen WebView, so the
// installed APK always shows the latest online version — new features and
// fixes go live by redeploying the web build, with no APK reinstall.
//
// Build with:  flutter build apk --release --target lib/main_shell.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'shell_notifications.dart';
import 'shell_speech.dart';

/// The hosted web app. Update only if the GitHub Pages URL changes.
const String kAppUrl = 'https://margales1004.github.io/Task-board/';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ShellNotifications.init(); // set up the notifications channel early
  runApp(const ShellApp());
}

class ShellApp extends StatelessWidget {
  const ShellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'My Boards',
      debugShowCheckedModeBanner: false,
      home: WebShell(),
    );
  }
}

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F5F8))
      // The web app posts reminder requests here; the native side schedules
      // real OS notifications. Injecting this makes window.Notifier exist, so
      // the web app knows reminders are available.
      ..addJavaScriptChannel(
        'Notifier',
        onMessageReceived: (JavaScriptMessage message) {
          ShellNotifications.handleMessage(message.message);
        },
      )
      // Voice dictation: the web app posts start/stop here; results are pushed
      // back into the page via runJavaScript.
      ..addJavaScriptChannel(
        'SpeechBridge',
        onMessageReceived: (JavaScriptMessage message) {
          ShellSpeech.handle(message.message, _controller);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            // Only surface top-level load failures, not sub-resource ones.
            if ((err.isForMainFrame ?? true) && mounted) {
              setState(() {
                _loading = false;
                _error = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(kAppUrl));
  }

  Future<void> _reload() async {
    setState(() {
      _error = false;
      _loading = true;
    });
    await _controller.loadRequest(Uri.parse(kAppUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Let the web app handle "back" via browser history when possible.
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F8),
        body: SafeArea(
          child: _error ? _errorView() : _webView(),
        ),
      ),
    );
  }

  Widget _webView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF16222F)),
          ),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📡', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 14),
            const Text(
              "Couldn't reach the app",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF68788A)),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _reload,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16222F),
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
