import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../models/source.dart';

/// Represents a capture request from a deep link
class CaptureRequest {
  final String text;
  final String? sourceUrl;
  final String? sourceTitle;
  final SourceType suggestedType;
  
  CaptureRequest({
    required this.text,
    this.sourceUrl,
    this.sourceTitle,
    this.suggestedType = SourceType.other,
  });
  
  factory CaptureRequest.fromUri(Uri uri) {
    final text = uri.queryParameters['text'] ?? '';
    final sourceUrl = uri.queryParameters['url'];
    final sourceTitle = uri.queryParameters['title'];
    final typeStr = uri.queryParameters['type'] ?? 'other';
    
    return CaptureRequest(
      text: text,
      sourceUrl: sourceUrl,
      sourceTitle: sourceTitle,
      suggestedType: _parseSourceType(typeStr),
    );
  }
  
  static SourceType _parseSourceType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'article':
        return SourceType.article;
      case 'video':
        return SourceType.video;
      case 'podcast':
        return SourceType.podcast;
      case 'book':
        return SourceType.book;
      case 'social':
      case 'social_post':
        return SourceType.social_post;
      case 'reels':
        return SourceType.reels;
      default:
        return SourceType.other;
    }
  }
}

/// Service to handle deep links for the cortex:// protocol
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  
  StreamSubscription<Uri>? _subscription;
  final StreamController<CaptureRequest> _captureController = 
      StreamController<CaptureRequest>.broadcast();
  
  /// Stream of capture requests from deep links
  Stream<CaptureRequest> get captureStream => _captureController.stream;
  
  Future<CaptureRequest?> init() async {
    // 1. ALWAYS start listening for subsequent links first
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      if (_isCaptureLink(uri)) {
        final request = CaptureRequest.fromUri(uri);
        _captureController.add(request);
      }
    });

    // 2. Then check for initial link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null && _isCaptureLink(initialUri)) {
        return CaptureRequest.fromUri(initialUri);
      }
    } catch (e) {
      rethrow;
    }
    
    return null;
  }
  
  bool _isCaptureLink(Uri uri) {
    return uri.scheme == 'cortex' && uri.host == 'capture';
  }
  
  void dispose() {
    _subscription?.cancel();
    _captureController.close();
  }
}
