import 'package:hive/hive.dart';

part 'fact.g.dart';

/// A single piece of knowledge (up to one paragraph)
@HiveType(typeId: 2)
class Fact extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String content;

  @HiveField(2)
  final String sourceId;

  @HiveField(3)
  List<String> subjects;

  @HiveField(4)
  String? imageUrl;

  @HiveField(5)
  String? ocrText;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  // SRS (Spaced Repetition) fields
  @HiveField(8)
  int repetitions;

  @HiveField(9)
  double easeFactor;

  @HiveField(10)
  int interval; // days until next review

  @HiveField(11)
  DateTime? nextReviewAt;

  // Phase 2: Embeddings
  @HiveField(12)
  List<double>? embedding;

  Fact({
    required this.id,
    required this.content,
    required this.sourceId,
    required this.subjects,
    this.imageUrl,
    this.ocrText,
    required this.createdAt,
    required this.updatedAt,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.nextReviewAt,
    this.embedding,
  });

  /// Create a new fact with defaults
  factory Fact.create({
    required String id,
    required String content,
    required String sourceId,
    List<String>? subjects,
    String? imageUrl,
    String? ocrText,
  }) {
    final now = DateTime.now();
    return Fact(
      id: id,
      content: content,
      sourceId: sourceId,
      subjects: subjects ?? [],
      imageUrl: imageUrl,
      ocrText: ocrText,
      createdAt: now,
      updatedAt: now,
      repetitions: 0,
      easeFactor: 2.5,
      interval: 0,
      nextReviewAt: now, // Due immediately
    );
  }

  /// Check if this fact is due for review
  bool get isDueForReview {
    if (nextReviewAt == null) return true;
    return DateTime.now().isAfter(nextReviewAt!);
  }

  /// Get the display text (content or OCR text)
  String get displayText => content.isNotEmpty ? content : (ocrText ?? '');
}
