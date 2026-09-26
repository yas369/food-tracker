import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app shows icons, never emoji: emoji look different on every phone and
/// clash with the icon style. This fails if one creeps back into the code.
void main() {
  test('no emoji anywhere in the app', () {
    // Emoji and pictographs, dingbats and symbols that phones draw as emoji
    // (such as ✓ ✂ ♂), arrows, variation selectors, and full-width forms.
    final emoji = RegExp('[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{25A0}-\u{25FF}\u{FE0F}\u{200D}\u{FF01}-\u{FF60}]', unicode: true);
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue; // comments may use arrows
        if (emoji.hasMatch(lines[i])) found.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(found, isEmpty);
  });
}
