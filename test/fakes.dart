import 'dart:convert';
import 'dart:io';

import 'package:platecheck/models.dart';
import 'package:platecheck/reminders.dart';
import 'package:platecheck/services/notifications.dart';
import 'package:platecheck/services/steps.dart';
import 'package:platecheck/services/storage.dart';

class MemoryStorage extends Storage {
  MemoryStorage([this.saved]);
  String? saved;
  @override
  Future<AppData> load() async => saved == null ? AppData() : AppData.fromJson(jsonDecode(saved!));
  @override
  Future<void> save(AppData d) async => saved = jsonEncode(d.toJson());
  @override
  Future<File> writeBackup(AppData d, String name) async => File(name);
}

class FakeNotifications extends Notifications {
  List<PlannedReminder> scheduled = [];
  final once = <(int, DateTime)>[];
  bool granted = true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> get allowed async => granted;
  @override
  Future<bool> get exactAllowed async => true;
  @override
  Future<bool> request() async => granted = true;
  @override
  Future<int> replaceAll(List<PlannedReminder> list) async {
    scheduled = list;
    return list.length - 1;
  }

  @override
  Future<void> scheduleOnce(int id, String title, String body, DateTime at, {String payload = ''}) async => once.add((id, at));
  @override
  Future<void> showNow(int id, String title, String body, {String payload = ''}) async {}
}

class FakeSteps extends StepSensor {
  @override
  bool get supported => false;
}
