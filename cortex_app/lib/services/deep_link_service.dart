import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/source.dart';

/// Represents a capture request from a deep link
class CaptureRequest {
  final String text; // Represents 'thought' or 'content'
  final String? quote; 
  final String? sourceUrl;
  final String? sourceTitle;
  final SourceType suggestedType;
  final int? pageNumber;
  final bool isSilent;
  
  CaptureRequest({
    required this.text,
    this.quote,
    this.sourceUrl,
    this.sourceTitle,
    this.suggestedType = SourceType.other,
    this.pageNumber,
    this.isSilent = false,
  });
  
  factory CaptureRequest.fromUri(Uri uri) {
    // We accept 'thought' or 'text' as the main content
    final text = uri.queryParameters['thought'] ?? uri.queryParameters['text'] ?? '';
    final quote = uri.queryParameters['quote'];
    final sourceUrl = uri.queryParameters['url'];
    final sourceTitle = uri.queryParameters['title'];
    final typeStr = uri.queryParameters['type'] ?? 'other';
    final pageNumber = int.tryParse(uri.queryParameters['page'] ?? '');
    final isSilent = uri.queryParameters['silent']?.toLowerCase() == 'true';
    
    return CaptureRequest(
      text: text,
      quote: quote,
      sourceUrl: sourceUrl,
      sourceTitle: sourceTitle,
      suggestedType: _parseSourceType(typeStr),
      pageNumber: pageNumber,
      isSilent: isSilent,
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
      case 'conversation':
        return SourceType.conversation;
      case 'pdf':
      case 'document':
        return SourceType.document;
      case 'course':
        return SourceType.course;
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
    final prefs = await SharedPreferences.getInstance();
    
    // 1. ALWAYS start listening for subsequent links first
    _subscription = _appLinks.uriLinkStream.listen((uri) async {
      if (_isCaptureLink(uri)) {
        final request = CaptureRequest.fromUri(uri);
        // Persist as handled
        await prefs.setString('last_handled_link', uri.toString());
        _captureController.add(request);
      }
    });

    // 2. Then check for initial link with deduplication
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null && _isCaptureLink(initialUri)) {
        final lastHandled = prefs.getString('last_handled_link');
        final currentLink = initialUri.toString();
        
        // Skip if this link was already handled (likely OS cache)
        if (lastHandled == currentLink) {
          debugPrint('DeepLinkService: Skipping already handled initial link');
          return null;
        }
        
        // Persist as handled
        await prefs.setString('last_handled_link', currentLink);
        return CaptureRequest.fromUri(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService Error: $e');
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
