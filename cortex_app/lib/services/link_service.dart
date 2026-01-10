import 'package:uuid/uuid.dart';
import '../models/fact.dart';
import '../models/fact_link.dart';
import 'storage_service.dart';

/// Service for managing bi-directional links between facts
class LinkService {
  final StorageService storage;
  final Uuid _uuid = const Uuid();
  
  // Regex to match [[link text]] pattern
  static final RegExp linkPattern = RegExp(r'\[\[([^\]]+)\]\]');
  
  LinkService(this.storage);
  
  /// Parse all [[links]] from fact content
  List<String> parseLinks(String content) {
    final matches = linkPattern.allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }
  
  /// Check if content contains any [[links]]
  bool hasLinks(String content) {
    return linkPattern.hasMatch(content);
  }
  
  /// Find a fact by its content (for linking)
  /// Returns the best matching fact based on content similarity
  Fact? findFactByContent(String linkText, List<Fact> allFacts) {
    final searchText = linkText.toLowerCase().trim();
    
    // First, try exact match
    for (final fact in allFacts) {
      if (fact.content.toLowerCase().contains(searchText)) {
        return fact;
      }
    }
    
    // Then try partial match (first few words)
    final searchWords = searchText.split(' ').take(3).join(' ');
    for (final fact in allFacts) {
      if (fact.content.toLowerCase().contains(searchWords)) {
        return fact;
      }
    }
    
    return null;
  }
  
  /// Create links for a fact based on its content
  Future<List<FactLink>> createLinksForFact(
    Fact fact,
    List<Fact> allFacts,
    List<FactLink> existingLinks,
  ) async {
    final linkTexts = parseLinks(fact.content);
    final newLinks = <FactLink>[];
    
    for (final linkText in linkTexts) {
      // Find target fact
      final targetFact = findFactByContent(linkText, allFacts);
      if (targetFact == null || targetFact.id == fact.id) continue;
      
      // Check if link already exists
      final exists = existingLinks.any((l) =>
          l.sourceFactId == fact.id && l.targetFactId == targetFact.id);
      if (exists) continue;
      
      // Create new link
      final link = FactLink.create(
        id: _uuid.v4(),
        sourceFactId: fact.id,
        targetFactId: targetFact.id,
        linkText: linkText,
      );
      newLinks.add(link);
    }
    
    return newLinks;
  }
  
  /// Get all links where this fact is the source (outgoing links)
  List<FactLink> getOutgoingLinks(String factId, List<FactLink> allLinks) {
    return allLinks.where((l) => l.sourceFactId == factId).toList();
  }
  
  /// Get all links where this fact is the target (backlinks)
  List<FactLink> getBacklinks(String factId, List<FactLink> allLinks) {
    return allLinks.where((l) => l.targetFactId == factId).toList();
  }
  
  /// Get total link count for a fact (incoming + outgoing)
  int getLinkCount(String factId, List<FactLink> allLinks) {
    return allLinks.where((l) => 
        l.sourceFactId == factId || l.targetFactId == factId).length;
  }
  
  /// Search facts for autocomplete when typing [[
  List<Fact> searchForAutocomplete(String query, List<Fact> allFacts) {
    if (query.isEmpty) {
      // Return recent facts
      final sorted = List<Fact>.from(allFacts);
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted.take(10).toList();
    }
    
    final searchText = query.toLowerCase();
    return allFacts.where((fact) {
      return fact.content.toLowerCase().contains(searchText) ||
             fact.subjects.any((s) => s.toLowerCase().contains(searchText));
    }).take(10).toList();
  }
  
  /// Format content with links as rich text spans
  /// Returns a list of TextSpan-like data for rendering
  List<ContentSpan> parseContentSpans(String content) {
    final spans = <ContentSpan>[];
    int lastEnd = 0;
    
    for (final match in linkPattern.allMatches(content)) {
      // Add text before this match
      if (match.start > lastEnd) {
        spans.add(ContentSpan(
          text: content.substring(lastEnd, match.start),
          isLink: false,
        ));
      }
      
      // Add the link
      spans.add(ContentSpan(
        text: match.group(1)!,
        isLink: true,
        fullMatch: match.group(0)!,
      ));
      
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < content.length) {
      spans.add(ContentSpan(
        text: content.substring(lastEnd),
        isLink: false,
      ));
    }
    
    return spans;
  }
}

/// Represents a span of content (either plain text or a link)
class ContentSpan {
  final String text;
  final bool isLink;
  final String? fullMatch; // The full [[text]] match
  
  ContentSpan({
    required this.text,
    required this.isLink,
    this.fullMatch,
  });
}
