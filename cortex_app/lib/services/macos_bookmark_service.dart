import 'dart:io';

import 'package:flutter/services.dart';

class MacosBookmarkResult {
  final String path;
  final bool isStale;

  const MacosBookmarkResult({
    required this.path,
    required this.isStale,
  });
}

class MacosBookmarkService {
  static const MethodChannel _channel = MethodChannel('cortex_app/macos_bookmarks');

  static bool get _isSupported => Platform.isMacOS;

  static Future<String?> createBookmark(String path) async {
    if (!_isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('createBookmark', path);
    } catch (_) {
      return null;
    }
  }

  static Future<MacosBookmarkResult?> resolveBookmark(String bookmark) async {
    if (!_isSupported) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('resolveBookmark', bookmark);
      final path = result?['path'] as String?;
      final stale = result?['stale'] as bool? ?? false;
      if (path == null) return null;
      return MacosBookmarkResult(path: path, isStale: stale);
    } catch (_) {
      return null;
    }
  }

  static Future<void> stopAccessing(String bookmark) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('stopAccessing', bookmark);
    } catch (_) {
      // ignore
    }
  }
}
