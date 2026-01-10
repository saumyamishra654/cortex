import 'package:hive/hive.dart';

part 'smart_collection.g.dart';

/// Filter field options for smart collections
@HiveType(typeId: 4)
enum FilterField {
  @HiveField(0)
  source,
  @HiveField(1)
  subject,
  @HiveField(2)
  createdAt,
  @HiveField(3)
  linkCount,
  @HiveField(4)
  hasEmbedding,
  @HiveField(5)
  isDue,
  @HiveField(6)
  content,
}

/// Filter operator options
@HiveType(typeId: 5)
enum FilterOperator {
  @HiveField(0)
  equals,
  @HiveField(1)
  notEquals,
  @HiveField(2)
  contains,
  @HiveField(3)
  greaterThan,
  @HiveField(4)
  lessThan,
  @HiveField(5)
  isTrue,
  @HiveField(6)
  isFalse,
}

/// Sort order options
@HiveType(typeId: 6)
enum SortField {
  @HiveField(0)
  createdAt,
  @HiveField(1)
  updatedAt,
  @HiveField(2)
  linkCount,
  @HiveField(3)
  nextReviewAt,
}

/// A filter condition for smart collections
@HiveType(typeId: 7)
class CollectionFilter {
  @HiveField(0)
  final FilterField field;

  @HiveField(1)
  final FilterOperator operator;

  @HiveField(2)
  final String value;

  CollectionFilter({
    required this.field,
    required this.operator,
    required this.value,
  });
  
  /// Human-readable description of this filter
  String get description {
    final fieldName = field.name;
    final opName = _operatorLabel(operator);
    return '$fieldName $opName ${value.isNotEmpty ? value : ""}';
  }
  
  String _operatorLabel(FilterOperator op) {
    switch (op) {
      case FilterOperator.equals:
        return 'is';
      case FilterOperator.notEquals:
        return 'is not';
      case FilterOperator.contains:
        return 'contains';
      case FilterOperator.greaterThan:
        return '>';
      case FilterOperator.lessThan:
        return '<';
      case FilterOperator.isTrue:
        return 'is true';
      case FilterOperator.isFalse:
        return 'is false';
    }
  }
}

/// A smart collection with dynamic filters
@HiveType(typeId: 8)
class SmartCollection extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String icon; // Material icon name

  @HiveField(3)
  List<CollectionFilter> filters;

  @HiveField(4)
  SortField sortField;

  @HiveField(5)
  bool sortDescending;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final bool isBuiltIn; // Cannot be deleted

  SmartCollection({
    required this.id,
    required this.name,
    required this.icon,
    required this.filters,
    required this.sortField,
    required this.sortDescending,
    required this.createdAt,
    this.isBuiltIn = false,
  });

  factory SmartCollection.create({
    required String id,
    required String name,
    String icon = 'folder',
    List<CollectionFilter>? filters,
    SortField sortField = SortField.createdAt,
    bool sortDescending = true,
    bool isBuiltIn = false,
  }) {
    return SmartCollection(
      id: id,
      name: name,
      icon: icon,
      filters: filters ?? [],
      sortField: sortField,
      sortDescending: sortDescending,
      createdAt: DateTime.now(),
      isBuiltIn: isBuiltIn,
    );
  }
}
