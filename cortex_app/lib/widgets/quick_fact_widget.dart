import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class QuickFactWidget extends StatefulWidget {
  final String sourceId;
  final bool isMiniMode;
  final VoidCallback? onFactAdded;
  final bool showQuoteOptions;
  final Future<void> Function({
    required String content, 
    String? quote, 
    int? pageNumber,
    List<String>? subjects,
  })? onSave;

  const QuickFactWidget({
    super.key,
    required this.sourceId,
    this.isMiniMode = false,
    this.onFactAdded,
    this.onSave,
    this.showQuoteOptions = true,
  });

  @override
  State<QuickFactWidget> createState() => _QuickFactWidgetState();
}

class _QuickFactWidgetState extends State<QuickFactWidget> {
  final TextEditingController _contentController = TextEditingController(); // Thought/Note
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  
  bool _isExpanded = false;
  List<String> _tags = [];
  bool _isSaving = false;
  final FocusNode _contentFocusNode = FocusNode();

  @override
  void dispose() {
    _contentController.dispose();
    _quoteController.dispose();
    _pageController.dispose();
    _tagsController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _resetForm() {
    _contentController.clear();
    _quoteController.clear();
    _pageController.clear();
    _tagsController.clear();
    setState(() {
      _isExpanded = false;
      _isSaving = false;
      _tags = [];
    });
    // Keep focus for rapid entry if in mini mode?
    // Maybe better to dismiss keyboard on mobile, but keep strictly focused on desktop.
    // For now, let's keep it simple.
  }

  Future<void> _submitFact() async {
    final content = _contentController.text.trim();
    final quote = _quoteController.text.trim();

    debugPrint('[QUICK_FACT] _submitFact. Content present: ${content.isNotEmpty}, Quote present: ${quote.isNotEmpty}');

    if (content.isEmpty && quote.isEmpty && _tags.isEmpty) {
      debugPrint('[QUICK_FACT] Submit ignored: all fields empty.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final pageNum = int.tryParse(_pageController.text.trim());
      debugPrint('[QUICK_FACT] Saving to source: ${widget.sourceId}. Callback provided: ${widget.onSave != null}');

      if (widget.onSave != null) {
        await widget.onSave!(
          content: content.isEmpty ? (quote.isEmpty ? 'Quick Note' : 'Quote') : content,
          quote: quote.isNotEmpty ? quote : null,
          pageNumber: pageNum,
          subjects: _tags.isNotEmpty ? _tags : null,
        );
      } else {
        final provider = Provider.of<DataProvider>(context, listen: false);
        await provider.addFact(
          content: content.isEmpty ? (quote.isEmpty ? 'Quick Note' : 'Quote') : content,
          quote: quote.isNotEmpty ? quote : null,
          sourceId: widget.sourceId,
          pageNumber: pageNum,
          subjects: _tags.isNotEmpty ? _tags : null,
        );
      }

      debugPrint('[QUICK_FACT] Save completed successfully.');

      if (mounted) {
        widget.onFactAdded?.call();
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Fact captured!'),
            duration: Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      debugPrint('[QUICK_FACT] ERROR during save: $e');
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMiniMode ? Colors.transparent : theme.colorScheme.surface,
        border: widget.isMiniMode ? null : Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Main Thought Field
                    TextField(
                      focusNode: _contentFocusNode,
                      controller: _contentController,
                      decoration: InputDecoration(
                        hintText: "What's on your mind?",
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          tooltip: _isExpanded ? 'Simple mode' : 'More options',
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitFact(),
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(height: 12),
                      if (widget.showQuoteOptions) ...[
                        TextField(
                          controller: _quoteController,
                          maxLines: 2,
                          style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                          decoration: InputDecoration(
                            hintText: 'Add quote...',
                            prefixIcon: const Icon(Icons.format_quote_rounded, size: 18),
                            fillColor: theme.colorScheme.surfaceContainerHigh,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _pageController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: theme.textTheme.bodyMedium,
                                decoration: InputDecoration(
                                  hintText: 'Page #',
                                  fillColor: theme.colorScheme.surfaceContainerHigh,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Tags Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_tags.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: _tags.map((tag) => Chip(
                                  label: Text(tag, style: const TextStyle(fontSize: 10)),
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                  onDeleted: () => setState(() => _tags.remove(tag)),
                                )).toList(),
                              ),
                            ),
                          TextField(
                            controller: _tagsController,
                            style: theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: 'Add tags...',
                              prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                              fillColor: theme.colorScheme.surfaceContainerHigh,
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onSubmitted: (value) {
                              final tag = value.trim();
                              if (tag.isNotEmpty && !_tags.contains(tag)) {
                                setState(() {
                                  _tags.add(tag);
                                  _tagsController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (_isExpanded) const SizedBox(width: 8),
              
              // Send Button
              IconButton.filled(
                onPressed: _isSaving ? null : _submitFact,
                icon: _isSaving 
                  ? const SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    ) 
                  : const Icon(Icons.arrow_upward_rounded),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
