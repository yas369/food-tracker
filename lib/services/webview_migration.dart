// One-time recovery of data from the earlier version of the app.
//
// That version was a web page inside Android's WebView, served from
// https://localhost, and kept its data in the WebView's localStorage under
// "plate-check.v1". This app uses the same WebView data folder, so a hidden
// WebView that loads a blank page *with the same origin* can read it back.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The start-up screen shows this WebView at 1×1 pixel while the recovery
/// runs, because some Android versions don't run pages that aren't on screen.
final migrationWebView = ValueNotifier<WebViewController?>(null);

Future<String?> readOldBrowserStorage() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final done = Completer<String?>();
  try {
    final c = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    await c.addJavaScriptChannel('PlateCheck', onMessageReceived: (m) {
      if (!done.isCompleted) done.complete(m.message.isEmpty ? null : m.message);
    });
    await c.setNavigationDelegate(NavigationDelegate(onPageFinished: (_) async {
      try {
        await c.runJavaScript("PlateCheck.postMessage(localStorage.getItem('plate-check.v1') || '')");
      } catch (_) {
        if (!done.isCompleted) done.complete(null);
      }
    }));
    migrationWebView.value = c;
    await c.loadHtmlString('<!doctype html><title>.</title>', baseUrl: 'https://localhost/');
    return await done.future.timeout(const Duration(seconds: 6), onTimeout: () => null);
  } catch (_) {
    return null;
  } finally {
    migrationWebView.value = null;
  }
}
