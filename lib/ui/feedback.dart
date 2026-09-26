// Confirmation after a change: a light buzz, a short message and a way back.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Show [message] with an Undo button. [buzz] adds a light vibration, for
/// logging food, so the tap is confirmed without reading anything.
void showUndo(BuildContext context, String message, VoidCallback undo, {bool buzz = false}) {
  if (buzz) HapticFeedback.lightImpact();
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      persist: false, // with an action it would otherwise stay until dismissed
      action: SnackBarAction(label: 'Undo', onPressed: undo),
    ),
  );
}
