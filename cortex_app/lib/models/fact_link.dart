import 'package:hive/hive.dart';

part 'fact_link.g.dart';

/// A bi-directional link between two facts
/// Created when a fact contains [[link text]] syntax
@HiveType(typeId: 3)
class FactLink extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sourceFactId; // Fact containing the [[link]]

  @HiveField(2)
  final String targetFactId; // Fact being linked to

  @HiveField(3)
  final String linkText; // Text inside [[...]]

  @HiveField(4)
  final DateTime createdAt;

  FactLink({
    required this.id,
    required this.sourceFactId,
    required this.targetFactId,
    required this.linkText,
    required this.createdAt,
  });

  factory FactLink.create({
    required String id,
    required String sourceFactId,
    required String targetFactId,
    required String linkText,
  }) {
    return FactLink(
      id: id,
      sourceFactId: sourceFactId,
      targetFactId: targetFactId,
      linkText: linkText,
      createdAt: DateTime.now(),
    );
  }
}
