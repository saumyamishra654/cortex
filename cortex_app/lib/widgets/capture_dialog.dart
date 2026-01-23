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
  final _subjectController = TextEditingController();
  List<String> _selectedSubjects = [];
  String? _selectedSourceId;
  bool _createNewSource = false;
  late TextEditingController _newSourceNameController;
  late TextEditingController _sourceUrlController;
  late SourceType _newSourceType;
  bool _isSaving = false;
  bool _isCluster = false;
  
  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.request.text);
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
    if (widget.request.sourceUrl == null || widget.request.sourceUrl!.isEmpty) {
      setState(() => _createNewSource = true);
      return;
    }
    
    final provider = context.read<DataProvider>();
    final requestUrl = widget.request.sourceUrl!;
    debugPrint('CaptureDialog: Matching against URL: $requestUrl');
    
    // 1. Try exact exact Base URL match (or very close to it)
    // 2. Try Longest Prefix Match among Cluster Sources
    
    Source? bestMatch;
    int bestMatchLength = -1;
    
    for (final source in provider.sources) {
      if (source.url == null || source.url!.isEmpty) continue;
      
      final sourceUrl = source.url!;
      
      if (source.isCluster) {
        // For clusters, check if request starts with source URL
        if (requestUrl.startsWith(sourceUrl)) {
          if (sourceUrl.length > bestMatchLength) {
            bestMatchLength = sourceUrl.length;
            bestMatch = source;
          }
        }
      } else {
        if (requestUrl == sourceUrl) {
           if (sourceUrl.length > bestMatchLength) {
            bestMatchLength = sourceUrl.length;
            bestMatch = source;
          }
        }
      }
    }
    
    // Fallback: If no match found, try the old "host match" logic 
    // but only if we didn't find a cluster match
    if (bestMatch == null) {
      bestMatch = provider.sources.cast<Source?>().firstWhere(
        (s) => s?.url != null && 
               requestUrl.contains(Uri.parse(s!.url!).host),
        orElse: () => null,
      );
    }
    
    if (bestMatch != null) {
      setState(() => _selectedSourceId = bestMatch!.id);
    } else {
      setState(() => _createNewSource = true);
    }
  }
  
  @override
  void dispose() {
    _contentController.dispose();
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
              // Content
              TextField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Fact',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Source selector
              if (!_createNewSource) ...[
                DropdownButtonFormField<String>(
                  value: _selectedSourceId,
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
                        final uri = Uri.parse(_sourceUrlController.text);
                        // Default to host + path without file extension?
                        // For now just keep it as is, user can edit.
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
  
  void _addSubject(String subject) {
    final trimmed = subject.trim();
    if (trimmed.isNotEmpty && !_selectedSubjects.contains(trimmed)) {
      setState(() {
        _selectedSubjects.add(trimmed);
        _subjectController.clear();
      });
    }
  }
  
  Future<void> _save() async {
    if (_contentController.text.trim().isEmpty) return;
    
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
      content: _contentController.text.trim(),
      sourceId: sourceId,
      subjects: _selectedSubjects.isNotEmpty ? _selectedSubjects : null,
      url: widget.request.sourceUrl, // Capture the specific page URL
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
