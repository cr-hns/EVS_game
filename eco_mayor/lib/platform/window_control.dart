import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:flutter/services.dart';

/// Borderless fullscreen on Windows (for the touchscreen demo board).
/// Talks to the "ecomayor/window" channel in windows/runner/flutter_window.cpp.
/// Everywhere else these calls do nothing.
class WindowControl {
  static const _channel = MethodChannel('ecomayor/window');
  static final ValueNotifier<bool> fullscreen = ValueNotifier(false);

  static bool get supported => !kIsWeb && Platform.isWindows;

  static Future<void> toggleFullscreen() async {
    if (!supported) return;
    try {
      fullscreen.value =
          await _channel.invokeMethod<bool>('toggleFullscreen') ?? false;
    } on PlatformException catch (_) {
      // Native side unavailable: ignore.
    } on MissingPluginException catch (_) {}
  }

  /// F11 toggles fullscreen; Esc leaves it.
  static void installKeyboardShortcuts() {
    if (!supported) return;
    HardwareKeyboard.instance.addHandler((event) {
      if (event is! KeyDownEvent) return false;
      if (event.logicalKey == LogicalKeyboardKey.f11) {
        toggleFullscreen();
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape && fullscreen.value) {
        toggleFullscreen();
        return true;
      }
      return false;
    });
  }
}
