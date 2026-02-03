import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddSourceScreen extends StatefulWidget {
  final Source? source; // If provided, we are in edit mode
  final SourceType? initialType;
  
  const AddSourceScreen({super.key, this.source, this.initialType});

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
  String? _filePath;
  List<String> _defaultTags = [];
  final _tagController = TextEditingController();
  Timer? _urlDebounce;
  bool _isFetchingTitle = false;
  String? _lastAutoFilledTitle;
  String? _lastAutoFilledUrl;

  @override
  void initState() {
    super.initState();
    if (widget.source != null) {
      _isEditing = true;
      _nameController.text = widget.source!.name;
      _urlController.text = widget.source!.url ?? '';
      _selectedType = widget.source!.type;
      _isCluster = widget.source!.isCluster;
      _filePath = widget.source!.filePath;
      _defaultTags = List<String>.from(widget.source!.defaultTags);
    } else if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }

    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlDebounce?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _nameController.dispose();
    _urlController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (_lastAutoFilledUrl == url) return;

    final currentName = _nameController.text.trim();
    final canAutoFill = currentName.isEmpty || currentName == _lastAutoFilledTitle;
    if (!canAutoFill) return;

    _urlDebounce?.cancel();
    _urlDebounce = Timer(const Duration(milliseconds: 600), () {
      _tryAutoFillTitleFromUrl(url);
    });
  }

  bool _isYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') || host.contains('youtu.be');
  }

  Future<void> _tryAutoFillTitleFromUrl(String url) async {
    if (_isFetchingTitle) return;
    if (!_isYouTubeUrl(url)) return;

    setState(() => _isFetchingTitle = true);
    try {
      final oembedUrl = Uri.parse(
        'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json',
      );
      final response = await http.get(oembedUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final title = data['title']?.toString().trim();
        final channel = data['author_name']?.toString().trim();
        final formattedTitle = [title, channel]
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .join(' - ');
        if (formattedTitle.isNotEmpty && mounted) {
          setState(() {
            _nameController.text = formattedTitle;
            _lastAutoFilledTitle = formattedTitle;
            _lastAutoFilledUrl = url;
            if (_selectedType == SourceType.other) {
              _selectedType = SourceType.video;
            }
          });
        }
      }
    } catch (_) {
      // Ignore auto-fill errors
    } finally {
      if (mounted) setState(() => _isFetchingTitle = false);
    }
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
                hintText: 'enter title here',
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
                suffixIcon: _isFetchingTitle
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: const OutlineInputBorder(),
                helperText: _isCluster 
                    ? 'Captures starting with this URL will be automatically added to this source.' 
                    : null,
                helperMaxLines: 2,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            
            // File Path Selection
            Text(
              'PDF Source File',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _filePath != null 
                              ? File(_filePath!).path.split('/').last 
                              : 'No file selected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _filePath != null ? null : theme.colorScheme.outline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_open_rounded, size: 18),
                        label: const Text('Select PDF'),
                      ),
                    ],
                  ),
                  if (_filePath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _filePath!,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Default Tags
            Text(
              'Default Tags',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_defaultTags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _defaultTags.map((tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _defaultTags.remove(tag)),
                )).toList(),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Add source-wide tag...',
                      isDense: true,
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _addTag(_tagController.text),
                ),
              ],
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

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        // Auto-fill name if empty
        if (_nameController.text.isEmpty) {
          _nameController.text = result.files.single.name.replaceAll('.pdf', '');
        }
        // Auto-select type
        _selectedType = SourceType.document;
      });
    }
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_defaultTags.contains(trimmed)) {
      setState(() {
        _defaultTags.add(trimmed);
        _tagController.clear();
      });
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
        updatedSource.filePath = _filePath;
        updatedSource.defaultTags = _defaultTags;
        updatedSource.updatedAt = DateTime.now();
        
        await provider.updateSource(updatedSource);
      } else {
        // Create new source
        await provider.addSource(
          name: name,
          type: _selectedType,
          url: url,
          isCluster: _isCluster,
          filePath: _filePath,
          defaultTags: _defaultTags,
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
