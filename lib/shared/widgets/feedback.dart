import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';

const _genericError = 'Something went wrong. Please try again.';

void showSnack(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Runs [action]; shows a snackbar and returns false when it fails.
/// Capture the messenger before awaiting anything: `ScaffoldMessenger.of(context)`.
Future<bool> guardAction(ScaffoldMessengerState messenger, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } on AppException catch (e) {
    showSnack(messenger, e.userMessage);
  } catch (_) {
    showSnack(messenger, _genericError);
  }
  return false;
}

/// Like [guardAction] but returns the action's value, or null on failure.
Future<T?> guardValue<T>(ScaffoldMessengerState messenger, Future<T> Function() action) async {
  try {
    return await action();
  } on AppException catch (e) {
    showSnack(messenger, e.userMessage);
  } catch (_) {
    showSnack(messenger, _genericError);
  }
  return null;
}
