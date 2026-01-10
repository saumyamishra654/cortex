import '../models/fact.dart';

/// Spaced Repetition Service using SM-2 algorithm
/// https://en.wikipedia.org/wiki/SuperMemo#Description_of_SM-2_algorithm
class SrsService {
  /// Quality ratings
  static const int qualityForgot = 0; // Complete failure
  static const int qualityHard = 3;   // Correct but difficult
  static const int qualityGood = 4;   // Correct with hesitation
  static const int qualityEasy = 5;   // Perfect response

  /// Process a review and return updated fact
  Fact processReview(Fact fact, int quality) {
    // Ensure quality is in valid range
    quality = quality.clamp(0, 5);

    int newRepetitions = fact.repetitions;
    double newEaseFactor = fact.easeFactor;
    int newInterval = fact.interval;

    if (quality >= 3) {
      // Correct response
      if (newRepetitions == 0) {
        newInterval = 1;
      } else if (newRepetitions == 1) {
        newInterval = 6;
      } else {
        newInterval = (fact.interval * fact.easeFactor).round();
      }
      newRepetitions++;
    } else {
      // Incorrect response - reset
      newRepetitions = 0;
      newInterval = 1;
    }

    // Update ease factor
    newEaseFactor = fact.easeFactor + 
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    
    // Ensure ease factor doesn't go below 1.3
    if (newEaseFactor < 1.3) {
      newEaseFactor = 1.3;
    }

    // Calculate next review date
    final nextReviewAt = DateTime.now().add(Duration(days: newInterval));

    return Fact(
      id: fact.id,
      content: fact.content,
      sourceId: fact.sourceId,
      subjects: fact.subjects,
      imageUrl: fact.imageUrl,
      ocrText: fact.ocrText,
      createdAt: fact.createdAt,
      updatedAt: DateTime.now(),
      repetitions: newRepetitions,
      easeFactor: newEaseFactor,
      interval: newInterval,
      nextReviewAt: nextReviewAt,
      embedding: fact.embedding,
    );
  }

  /// Get facts due for review, optionally shuffled
  List<Fact> getDueFactsShuffled(List<Fact> allFacts, {bool shuffle = true}) {
    final now = DateTime.now();
    final dueFacts = allFacts.where((f) {
      if (f.nextReviewAt == null) return true;
      return now.isAfter(f.nextReviewAt!);
    }).toList();

    if (shuffle) {
      dueFacts.shuffle();
    }

    return dueFacts;
  }

  /// Get all facts for random shuffle review (ignores SRS scheduling)
  List<Fact> getShuffledFacts(List<Fact> allFacts) {
    final shuffled = List<Fact>.from(allFacts);
    shuffled.shuffle();
    return shuffled;
  }

  /// Get statistics
  Map<String, int> getStats(List<Fact> allFacts) {
    final now = DateTime.now();
    final dueCount = allFacts.where((f) {
      if (f.nextReviewAt == null) return true;
      return now.isAfter(f.nextReviewAt!);
    }).length;

    final newCount = allFacts.where((f) => f.repetitions == 0).length;
    final learningCount = allFacts.where((f) => 
        f.repetitions > 0 && f.interval < 21).length;
    final matureCount = allFacts.where((f) => f.interval >= 21).length;

    return {
      'total': allFacts.length,
      'due': dueCount,
      'new': newCount,
      'learning': learningCount,
      'mature': matureCount,
    };
  }
}
