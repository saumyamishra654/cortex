import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';

class AddSourceScreen extends StatefulWidget {
  final Source? source; // If provided, we are in edit mode
  
  const AddSourceScreen({super.key, this.source});

  @override
  State<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends State<AddSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  SourceType _selectedType = SourceType.book;
  bool _isCluster = false;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.source != null) {
      _isEditing = true;
      _nameController.text = widget.source!.name;
      _urlController.text = widget.source!.url ?? '';
      _selectedType = widget.source!.type;
      _isCluster = widget.source!.isCluster;
    }
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
        title: Text(_isEditing ? 'Edit Source' : 'New Source'),
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
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),
            
            // Cluster Toggle
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Group captures from this URL'),
              subtitle: Text(
                'Treat this as a parent container (e.g. for sub-pages or tweets)',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              value: _isCluster,
              onChanged: (val) => setState(() => _isCluster = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: _isCluster ? 'Base URL Pattern' : 'Link (Optional)',
                hintText: _isCluster ? 'https://example.com/blog/' : 'https://...',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                helperText: _isCluster 
                    ? 'Captures starting with this URL will be automatically added to this source.' 
                    : null,
                helperMaxLines: 2,
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
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              label: Text(_isEditing ? 'Save Changes' : 'Create Source'),
              icon: _isLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.save),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(SourceType type) {
    switch (type) {
      case SourceType.book: return 'Book';
      case SourceType.article: return 'Article';
      case SourceType.podcast: return 'Podcast';
      case SourceType.video: return 'Video';
      case SourceType.conversation: return 'Conversation';
      case SourceType.course: return 'Course';
      case SourceType.research_paper: return 'Paper';
      case SourceType.audiobook: return 'Audiobook';
      case SourceType.reels: return 'Reels / Shorts';
      case SourceType.social_post: return 'Social Post';
      case SourceType.document: return 'Document';
      case SourceType.other: return 'Other';
    }
  }

  IconData _getTypeIcon(SourceType type) {
    switch (type) {
      case SourceType.book: return Icons.menu_book_rounded;
      case SourceType.article: return Icons.article_rounded;
      case SourceType.podcast: return Icons.podcasts_rounded;
      case SourceType.video: return Icons.video_library_rounded;
      case SourceType.conversation: return Icons.chat_rounded;
      case SourceType.course: return Icons.school_rounded;
      case SourceType.other: return Icons.folder_rounded;
      case SourceType.research_paper: return Icons.science_rounded;
      case SourceType.audiobook: return Icons.headphones_rounded;
      case SourceType.reels: return Icons.smartphone_rounded;
      case SourceType.social_post: return Icons.public_rounded;
      case SourceType.document: return Icons.description_rounded;
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final provider = context.read<DataProvider>();
      final name = _nameController.text.trim();
      final url = _urlController.text.trim().isEmpty ? null : _urlController.text.trim();
      
      if (_isEditing) {
        // Update existing source
        final updatedSource = widget.source!;
        updatedSource.name = name;
        updatedSource.type = _selectedType;
        updatedSource.url = url;
        updatedSource.isCluster = _isCluster;
        updatedSource.updatedAt = DateTime.now();
        
        await provider.updateSource(updatedSource);
      } else {
        // Create new source
        await provider.addSource(
          name: name,
          type: _selectedType,
          url: url,
          isCluster: _isCluster,
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
