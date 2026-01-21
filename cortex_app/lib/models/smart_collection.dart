import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  @HiveField(7)
  id,
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
  @HiveField(7)
  isIn, // value is comma-separated list
}

/// Type of smart collection
@HiveType(typeId: 9)
enum CollectionType {
  @HiveField(0)
  manual,  // User created
  @HiveField(1)
  cluster, // Auto-generated semantic cluster
  @HiveField(2)
  structure, // Auto-generated structural component (island/bridge)
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
      case FilterOperator.isIn:
        return 'is in';
    }
  }


  factory CollectionFilter.fromJson(Map<String, dynamic> json) {
    return CollectionFilter(
      field: FilterField.values.firstWhere(
        (e) => e.name == json['field'],
        orElse: () => FilterField.content,
      ),
      operator: FilterOperator.values.firstWhere(
        (e) => e.name == json['operator'],
        orElse: () => FilterOperator.contains,
      ),
      value: json['value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field.name,
      'operator': operator.name,
      'value': value,
    };
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
  
  @HiveField(8)
  final CollectionType type;
  
  @HiveField(9)
  final Map<String, String> dynamicParams; // For storing cluster IDs, topics, etc.

  SmartCollection({
    required this.id,
    required this.name,
    required this.icon,
    required this.filters,
    required this.sortField,
    required this.sortDescending,
    required this.createdAt,
    this.isBuiltIn = false,
    this.type = CollectionType.manual,
    this.dynamicParams = const {},
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
      type: CollectionType.manual,
    );
  }
  
  factory SmartCollection.dynamic({
    required String id,
    required String name,
    required CollectionType type,
    String icon = 'auto_awesome',
    Map<String, String> params = const {},
    List<CollectionFilter> filters = const [],
  }) {
    return SmartCollection(
      id: id,
      name: name,
      icon: icon,
      filters: filters,
      sortField: SortField.linkCount, // Default for insights
      sortDescending: true,
      createdAt: DateTime.now(),
      isBuiltIn: false,
      type: type,
      dynamicParams: params,
    );
  }

  /// Create from JSON (for Firestore)
  factory SmartCollection.fromJson(Map<String, dynamic> json) {
    return SmartCollection(
      id: json['id'],
      name: json['name'],
      icon: json['icon'] ?? 'folder',
      filters: (json['filters'] as List<dynamic>?)
              ?.map((e) => CollectionFilter.fromJson(e))
              .toList() ??
          [],
      sortField: SortField.values.firstWhere(
        (e) => e.name == json['sortField'],
        orElse: () => SortField.createdAt,
      ),
      sortDescending: json['sortDescending'] ?? true,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isBuiltIn: json['isBuiltIn'] ?? false,
      type: CollectionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CollectionType.manual,
      ),
      dynamicParams: Map<String, String>.from(json['dynamicParams'] ?? {}),
    );
  }

  /// Convert to JSON (for Firestore)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'filters': filters.map((e) => e.toJson()).toList(),
      'sortField': sortField.name,
      'sortDescending': sortDescending,
      'createdAt': Timestamp.fromDate(createdAt),
      'isBuiltIn': isBuiltIn,
      'type': type.name,
      'dynamicParams': dynamicParams,
    };
  }
}

