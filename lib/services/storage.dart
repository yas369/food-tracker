// Saving on the phone.
//
// Everything is one JSON file in the app's private storage,
// plate-check-state.json. It is the same file, in the same folder, that the
// earlier version of the app wrote, so an update picks it up as it is.
// Android's own backup covers this folder.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'webview_migration.dart';

const stateFileName = 'plate-check-state.json';
const _webKey = 'plate-check.v1';

class Storage {
  File? _file;

  Future<File> _stateFile() async => _file ??= File('${(await getApplicationSupportDirectory()).path}/$stateFileName');

  /// Load saved data. On first start after the update, also recover data the
  /// earlier version kept only in its browser storage, and keep whichever copy
  /// is newer.
  Future<AppData> load() async {
    if (kIsWeb) {
      final raw = (await SharedPreferences.getInstance()).getString(_webKey);
      return raw == null ? AppData() : AppData.fromJson(jsonDecode(raw));
    }
    AppData? fromFile;
    try {
      final f = await _stateFile();
      if (await f.exists()) fromFile = AppData.fromJson(jsonDecode(await f.readAsString()));
    } catch (_) {}
    if (fromFile == null || !fromFile.me.onboarded) {
      // The earlier version saved to browser storage first; recover it once.
      final raw = await readOldBrowserStorage();
      if (raw != null) {
        try {
          final old = AppData.fromJson(jsonDecode(raw));
          if (fromFile == null || old.savedAt > fromFile.savedAt) {
            await save(old);
            return old;
          }
        } catch (_) {}
      }
    }
    return fromFile ?? AppData();
  }

  /// Write atomically: a new file, then rename over the old one, so a crash
  /// mid-save can't leave half a file.
  Future<void> save(AppData d) async {
    final json = jsonEncode(d.toJson());
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).setString(_webKey, json);
      return;
    }
    final f = await _stateFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
  }

  Future<File> writeBackup(AppData d, String name) async {
    final f = File('${(await getTemporaryDirectory()).path}/$name');
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert(d.toJson()));
    return f;
  }
}
