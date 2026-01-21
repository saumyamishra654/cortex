import 'package:hive/hive.dart';

part 'source.g.dart';

/// Type of knowledge source
@HiveType(typeId: 0)
enum SourceType {
  @HiveField(0)
  book,
  @HiveField(1)
  article,
  @HiveField(2)
  podcast,
  @HiveField(3)
  video,
  @HiveField(4)
  conversation,
  @HiveField(5)
  course,
  @HiveField(6)
  other,
}

/// A source/container for facts (book, podcast, article, etc.)
@HiveType(typeId: 1)
class Source extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  SourceType type;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  String? url;

  Source({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.url,
  });

  /// Create a new source with auto-generated timestamps
  factory Source.create({
    required String id,
    required String name,
    required SourceType type,
    String? url,
  }) {
    final now = DateTime.now();
    return Source(
      id: id,
      name: name,
      type: type,
      createdAt: now,
      updatedAt: now,
      url: url,
    );
  }

  /// Get icon for source type
  String get iconName {
    switch (type) {
      case SourceType.book:
        return 'book';
      case SourceType.article:
        return 'article';
      case SourceType.podcast:
        return 'podcasts';
      case SourceType.video:
        return 'video_library';
      case SourceType.conversation:
        return 'chat';
      case SourceType.course:
        return 'school';
      case SourceType.other:
        return 'folder';
    }
  }

  /// Get display label for source type
  String get typeLabel {
    switch (type) {
      case SourceType.book:
        return 'Book';
      case SourceType.article:
        return 'Article';
      case SourceType.podcast:
        return 'Podcast';
      case SourceType.video:
        return 'Video';
      case SourceType.conversation:
        return 'Conversation';
      case SourceType.course:
        return 'Course';
      case SourceType.other:
        return 'Other';
    }
  }
}
