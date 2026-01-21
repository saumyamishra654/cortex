import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/smart_collection.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';
import '../services/collection_service.dart';

class CreateCollectionDialog extends StatefulWidget {
  const CreateCollectionDialog({super.key});

  @override
  State<CreateCollectionDialog> createState() => _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<CreateCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _collectionService = CollectionService();
  
  // Multi-select state
  List<String> _selectedSources = [];
  List<String> _selectedSourceTypes = [];
  List<String> _selectedTags = [];
  
  SortField _sortField = SortField.createdAt;
  bool _sortDescending = true;
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  String _getTypeLabel(SourceType type) {
    switch (type) {
      case SourceType.book: return 'Book';
      case SourceType.article: return 'Article';
      case SourceType.podcast: return 'Podcast';
      case SourceType.video: return 'Video';
      case SourceType.conversation: return 'Conversation';
      case SourceType.course: return 'Course';
      case SourceType.other: return 'Other';
      case SourceType.research_paper: return 'Research Paper';
      case SourceType.audiobook: return 'Audiobook';
      case SourceType.reels: return 'Reels / Shorts';
      case SourceType.social_post: return 'Social Post';
      case SourceType.document: return 'Document';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    
    // Calculate matching facts count for preview
    final previewFilters = _buildFilters();
    final matchingFacts = _collectionService.executeFilters(
      provider.facts, 
      previewFilters, 
      provider.factLinks,
      {for (var s in provider.sources) s.id: s},
    );

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Collection',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Collection Name',
                  hintText: 'e.g., Philosophy Books',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Filters Header
              Text('Filters', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              
              // Source Multi-Selector
              _buildMultiSelectTile(
                context,
                label: 'Sources',
                items: provider.sources.map((s) => MapEntry(s.id, s.name)).toList(),
                selectedValues: _selectedSources,
                onChanged: (values) => setState(() => _selectedSources = values),
              ),
              const SizedBox(height: 12),

              // Source Type Multi-Selector
              _buildMultiSelectTile(
                context,
                label: 'Source Types',
                items: SourceType.values.map((t) => MapEntry(t.name, _getTypeLabel(t))).toList(),
                selectedValues: _selectedSourceTypes,
                onChanged: (values) => setState(() => _selectedSourceTypes = values),
              ),
              const SizedBox(height: 12),
              
              // Tag Multi-Selector
              _buildMultiSelectTile(
                context,
                label: 'Tags',
                items: provider.allSubjects.map((t) => MapEntry(t, t)).toList(),
                selectedValues: _selectedTags,
                onChanged: (values) => setState(() => _selectedTags = values),
              ),
              
              const SizedBox(height: 16),
              
              // Sort Options
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<SortField>(
                      value: _sortField,
                      decoration: const InputDecoration(
                        labelText: 'Sort By',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: SortField.createdAt,
                          child: Text('Date Created'),
                        ),
                        DropdownMenuItem(
                          value: SortField.linkCount,
                          child: Text('Most Connected'),
                        ),
                        DropdownMenuItem(
                          value: SortField.updatedAt,
                          child: Text('Last Updated'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _sortField = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _sortDescending = !_sortDescending),
                    icon: Icon(_sortDescending 
                      ? Icons.arrow_downward 
                      : Icons.arrow_upward
                    ),
                    tooltip: _sortDescending ? 'Descending' : 'Ascending',
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Preview Count
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list, 
                      size: 16, 
                      color: theme.colorScheme.onSurfaceVariant
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Matches ${matchingFacts.length} facts',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveCollection,
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMultiSelectTile(
    BuildContext context, {
    required String label,
    required List<MapEntry<String, String>> items, // key: id, value: display
    required List<String> selectedValues,
    required ValueChanged<List<String>> onChanged,
  }) {
    final theme = Theme.of(context);
    // Helper to get display names for selected items
    String getSubtitle() {
      if (selectedValues.isEmpty) return 'Tap to select...';
      final names = selectedValues.map((id) {
        final entry = items.firstWhere(
          (e) => e.key == id, 
          orElse: () => MapEntry(id, '?')
        );
        return entry.value;
      }).join(', ');
      return names;
    }

    return InkWell(
      onTap: () async {
        final result = await showDialog<List<String>>(
          context: context,
          builder: (context) => _MultiSelectDialog(
            title: 'Select $label',
            items: items,
            initialSelected: selectedValues,
          ),
        );
        if (result != null) {
          onChanged(result);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          getSubtitle(),
          style: theme.textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
  
  List<CollectionFilter> _buildFilters() {
    final filters = <CollectionFilter>[];
    
    if (_selectedSources.isNotEmpty) {
      filters.add(CollectionFilter(
        field: FilterField.source,
        operator: FilterOperator.isIn,
        value: _selectedSources.join(','),
      ));
    }

    if (_selectedSourceTypes.isNotEmpty) {
      filters.add(CollectionFilter(
        field: FilterField.sourceType,
        operator: FilterOperator.isIn,
        value: _selectedSourceTypes.join(','),
      ));
    }
    
    if (_selectedTags.isNotEmpty) {
      filters.add(CollectionFilter(
        field: FilterField.subject,
        operator: FilterOperator.isIn,
        value: _selectedTags.join(','),
      ));
    }
    
    return filters;
  }
  
  void _saveCollection() {
    if (_formKey.currentState!.validate()) {
      final collection = SmartCollection.create(
        id: 'cust_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        filters: _buildFilters(),
        sortField: _sortField,
        sortDescending: _sortDescending,
        icon: 'folder',
      );
      
      Navigator.pop(context, collection);
    }
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<MapEntry<String, String>> items;
  final List<String> initialSelected;

  const _MultiSelectDialog({
    required this.title,
    required this.items,
    required this.initialSelected,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final isSelected = _selected.contains(item.key);
            return CheckboxListTile(
              title: Text(item.value),
              value: isSelected,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(item.key);
                  } else {
                    _selected.remove(item.key);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
