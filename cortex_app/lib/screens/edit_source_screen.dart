import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';

class EditSourceScreen extends StatefulWidget {
  final Source source;

  const EditSourceScreen({
    super.key,
    required this.source,
  });

  @override
  State<EditSourceScreen> createState() => _EditSourceScreenState();
}

class _EditSourceScreenState extends State<EditSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late SourceType _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.source.name);
    _urlController = TextEditingController(text: widget.source.url);
    _selectedType = widget.source.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Source'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Source Name',
                hintText: 'e.g., Atomic Habits, Huberman Lab',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Link (Optional)',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            Text(
              'Type',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SourceType.values.map((type) {
                final isSelected = type == _selectedType;
                return ChoiceChip(
                  label: Text(_getTypeLabel(type)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedType = type);
                    }
                  },
                  avatar: Icon(
                    _getTypeIcon(type),
                    size: 18,
                    color: isSelected 
                        ? theme.colorScheme.onPrimary 
                        : theme.colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(SourceType type) {
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
      case SourceType.research_paper:
        return 'Research Paper';
      case SourceType.audiobook:
        return 'Audiobook';
      case SourceType.reels:
        return 'Reels / Shorts';
      case SourceType.social_post:
        return 'Social Post';
      case SourceType.document:
        return 'Document';
    }
  }

  IconData _getTypeIcon(SourceType type) {
    switch (type) {
      case SourceType.book:
        return Icons.menu_book_rounded;
      case SourceType.article:
        return Icons.article_rounded;
      case SourceType.podcast:
        return Icons.podcasts_rounded;
      case SourceType.video:
        return Icons.video_library_rounded;
      case SourceType.conversation:
        return Icons.chat_rounded;
      case SourceType.course:
        return Icons.school_rounded;
      case SourceType.other:
        return Icons.folder_rounded;
      case SourceType.research_paper:
        return Icons.science_rounded;
      case SourceType.audiobook:
        return Icons.headphones_rounded;
      case SourceType.reels:
        return Icons.smartphone_rounded;
      case SourceType.social_post:
        return Icons.public_rounded;
      case SourceType.document:
        return Icons.description_rounded;
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final updatedSource = Source(
        id: widget.source.id,
        name: _nameController.text.trim(),
        type: _selectedType,
        createdAt: widget.source.createdAt,
        updatedAt: DateTime.now(),
        url: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
      );
      
      await context.read<DataProvider>().updateSource(updatedSource);
      
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showDeleteDialog(BuildContext context) {
    final provider = context.read<DataProvider>();
    final factCount = provider.getFactCountForSource(widget.source.id);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Source?'),
        content: Text(
          'This will delete "${widget.source.name}" and all $factCount facts. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteSource(widget.source.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close edit screen
              Navigator.pop(context); // Go back to home
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
