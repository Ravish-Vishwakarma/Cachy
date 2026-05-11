import 'package:flutter/material.dart';

/// Convenience utility for showing a floating snackbar message.
class SnackbarMessage {
  /// Displays a short [message] in a floating snackbar at the bottom.
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
