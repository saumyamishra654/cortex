import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';

class AddSourceScreen extends StatefulWidget {
  const AddSourceScreen({super.key});

  @override
  State<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends State<AddSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  SourceType _selectedType = SourceType.book;

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
        title: const Text('New Source'),
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
              onPressed: _submit,
              child: const Text('Create Source'),
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
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      await context.read<DataProvider>().addSource(
        name: _nameController.text.trim(),
        type: _selectedType,
        url: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
