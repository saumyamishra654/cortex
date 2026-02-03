import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';
import '../services/deep_link_service.dart';

/// A dialog for quickly capturing text from deep links
class CaptureDialog extends StatefulWidget {
  final CaptureRequest request;
  
  const CaptureDialog({super.key, required this.request});
  
  /// Show the capture dialog as a modal
  static Future<bool?> show(BuildContext context, CaptureRequest request) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CaptureDialog(request: request),
    );
  }

  @override
  State<CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<CaptureDialog> {
  late TextEditingController _contentController;
  late TextEditingController _quoteController;
  late TextEditingController _pageController;
  final _subjectController = TextEditingController();
  final List<String> _selectedSubjects = [];
  String? _selectedSourceId;
  bool _createNewSource = false;
  late TextEditingController _newSourceNameController;
  late TextEditingController _sourceUrlController;
  late SourceType _newSourceType;
  bool _isSaving = false;
  bool _isCluster = false;
  bool _showDetails = false;
  
  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.request.text);
    _quoteController = TextEditingController(text: widget.request.quote);
    _pageController = TextEditingController(text: widget.request.pageNumber?.toString() ?? '');
    
    // Auto show details if quote or page is present
    if (widget.request.quote != null || widget.request.pageNumber != null) {
      _showDetails = true;
    }
    
    _newSourceNameController = TextEditingController(
      text: widget.request.sourceTitle ?? 'Quick Capture',
    );
    _sourceUrlController = TextEditingController(
      text: widget.request.sourceUrl ?? '',
    );
    _newSourceType = widget.request.suggestedType;
    
    // Try to find existing source matching URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _findMatchingSource();
      } catch (e) {
        // Fallback to new source
        setState(() => _createNewSource = true);
      }
    });
  }

  void _findMatchingSource() {
    if (widget.request.sourceUrl != null && widget.request.sourceUrl!.isNotEmpty) {
      final provider = context.read<DataProvider>();
      final existingSource = provider.sources.cast<Source?>().firstWhere(
        (s) => s?.url == widget.request.sourceUrl || 
               (s?.isCluster == true && widget.request.sourceUrl!.contains(s!.url ?? '')),
        orElse: () => null,
      );
      
      if (existingSource != null) {
        setState(() {
          _selectedSourceId = existingSource.id;
        });
      } else {
        setState(() => _createNewSource = true);
      }
    } else {
      setState(() => _createNewSource = true);
    }
  }

  // Add subject tag
  void _addSubject(String value) {
    final tag = value.trim();
    if (tag.isNotEmpty && !_selectedSubjects.contains(tag)) {
        setState(() {
            _selectedSubjects.add(tag);
            _subjectController.clear();
        });
    }
  }
  
  @override
  void dispose() {
    _contentController.dispose();
    _quoteController.dispose();
    _pageController.dispose();
    _subjectController.dispose();
    _newSourceNameController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    
    return Material(
      type: MaterialType.transparency,
      child: AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bolt_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Quick Capture'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          minHeight: 300,
          maxHeight: 600,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content (Thought)
              TextField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Thought',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  hintText: 'Your thought or note...',
                ),
              ),
              const SizedBox(height: 12),
              
              // Toggle for Details (Quote / Page)
              InkWell(
                onTap: () => setState(() => _showDetails = !_showDetails),
                child: Row(
                  children: [
                    Icon(
                      _showDetails ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded,
                      color: theme.colorScheme.secondary,
                    ),
                    Text(
                      'Quote & Page Details',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_showDetails) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _quoteController,
                  maxLines: 3,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                  decoration: const InputDecoration(
                    labelText: 'Quote',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.format_quote_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _pageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Page #',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              
              // Source selector
              if (!_createNewSource) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedSourceId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    ...provider.sources.map((source) => DropdownMenuItem(
                      value: source.id,
                      child: Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                    const DropdownMenuItem(
                      value: '__new__',
                      child: Text('+ Create New Source'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == '__new__') {
                      setState(() => _createNewSource = true);
                    } else {
                      setState(() => _selectedSourceId = value);
                    }
                  },
                ),
              ] else ...[
                // New source form
                Text('New Source', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _newSourceNameController,
                  decoration: const InputDecoration(
                    labelText: 'Source Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: SourceType.values.map((type) {
                    final isSelected = type == _newSourceType;
                    return ChoiceChip(
                      label: Text(_getTypeLabel(type)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _newSourceType = type);
                      },
                    );
                  }).toList(),
                ),
                if (provider.sources.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _createNewSource = false),
                    child: const Text('Use Existing Source'),
                  ),
                ],
                const SizedBox(height: 12),
                
                // Cluster Toggle
                InkWell(
                  onTap: () {
                    setState(() {
                      _isCluster = !_isCluster;
                      // Auto-trim URL for clustering convenience
                      if (_isCluster && _sourceUrlController.text.isNotEmpty) {
                        try {
                          // ignore: unused_local_variable
                          final uri = Uri.parse(_sourceUrlController.text);
                        } catch (_) {}
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _isCluster,
                          onChanged: (v) => setState(() => _isCluster = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Group captures from this path', style: theme.textTheme.bodyMedium),
                            if (_isCluster)
                              Text(
                                'Future Links starting with this URL will be added to this source.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10, 
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Editable Base URL for Clusters
                if (_isCluster) ...[
                   const SizedBox(height: 8),
                   TextField(
                    controller: _sourceUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL Pattern',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                      isDense: true,
                      helperText: 'e.g. tensortonic.com/ml-math/',
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                   ),
                ],
              ],
              const SizedBox(height: 16),
              
              // Subject tags
              Text('Tags (optional)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (_selectedSubjects.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedSubjects.map((s) => Chip(
                    label: Text(s),
                    onDeleted: () => setState(() => _selectedSubjects.remove(s)),
                  )).toList(),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        hintText: 'Add tag...',
                        isDense: true,
                      ),
                      onSubmitted: _addSubject,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _addSubject(_subjectController.text),
                  ),
                ],
              ),
              
              // URL info (Read-only if not clustering, or just show original context)
              if (!_isCluster && widget.request.sourceUrl != null && widget.request.sourceUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Captured from:',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          Text(
                            widget.request.sourceUrl!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving 
              ? const SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('Save'),
        ),
      ],
      ),
    );
  }

  Future<void> _save() async {
    // Content shouldn't be empty, but if quote is present, allow content to be default or just "Quote"
    String finalContent = _contentController.text.trim();
    final String? finalQuote = _quoteController.text.trim().isNotEmpty ? _quoteController.text.trim() : null;
    
    if (finalContent.isEmpty) {
      if (finalQuote != null) {
        finalContent = 'Quote'; // Default title/thought
      } else {
        return; // Nothing to save
      }
    }
    
    setState(() => _isSaving = true);
    
    final provider = context.read<DataProvider>();
    String sourceId;
    
    // Create new source if needed
    if (_createNewSource) {
      final newSource = await provider.addSource(
        name: _newSourceNameController.text.trim().isEmpty 
            ? 'Quick Capture' 
            : _newSourceNameController.text.trim(),
        type: _newSourceType,
        url: _isCluster ? _sourceUrlController.text.trim() : widget.request.sourceUrl,
        isCluster: _isCluster,
      );
      sourceId = newSource.id;
    } else {
      sourceId = _selectedSourceId!;
    }
    
    // Save the fact
    await provider.addFact(
      content: finalContent,
      sourceId: sourceId,
      quote: finalQuote,
      pageNumber: int.tryParse(_pageController.text.trim()),
      subjects: _selectedSubjects.isNotEmpty ? _selectedSubjects : null,
      url: widget.request.sourceUrl, 
    );
    
    if (mounted) {
      Navigator.pop(context, true);
    }
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
      case SourceType.reels: return 'Reels';
      case SourceType.social_post: return 'Social';
      case SourceType.document: return 'Document';
      case SourceType.other: return 'Other';
    }
  }
}
