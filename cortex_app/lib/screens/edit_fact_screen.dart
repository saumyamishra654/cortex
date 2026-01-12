import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fact.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';

class EditFactScreen extends StatefulWidget {
  final Fact fact;

  const EditFactScreen({super.key, required this.fact});

  @override
  State<EditFactScreen> createState() => _EditFactScreenState();
}

class _EditFactScreenState extends State<EditFactScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contentController;
  final _subjectController = TextEditingController();
  late List<String> _selectedSubjects;
  late String _selectedSourceId;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.fact.content);
    _selectedSubjects = List.from(widget.fact.subjects);
    _selectedSourceId = widget.fact.sourceId;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    final existingSubjects = provider.allSubjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Fact'),
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
            // Source selector
            Text('Source', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSourceId,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: provider.sources.map((source) {
                return DropdownMenuItem(
                  value: source.id,
                  child: Row(
                    children: [
                      Icon(_getSourceIcon(source.type), size: 20),
                      const SizedBox(width: 8),
                      Text(source.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSourceId = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // Content input
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: 'Fact',
                hintText: 'Enter your fact or idea...',
                helperText: 'Use [[text]] to link to other facts',
                helperStyle: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontSize: 12,
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a fact';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Subject tags
            Text('Subject Tags', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // Selected subjects
            if (_selectedSubjects.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedSubjects.map((subject) {
                  return Chip(
                    label: Text(subject),
                    onDeleted: () {
                      setState(() {
                        _selectedSubjects.remove(subject);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Add subject input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      hintText: 'Add a subject tag...',
                      isDense: true,
                    ),
                    onSubmitted: _addSubject,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _addSubject(_subjectController.text),
                  icon: const Icon(Icons.add_circle_rounded),
                  color: theme.colorScheme.primary,
                ),
              ],
            ),

            // Existing subjects suggestion
            if (existingSubjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Existing subjects:', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: existingSubjects
                    .where((s) => !_selectedSubjects.contains(s))
                    .take(10)
                    .map((subject) {
                      return ActionChip(
                        label: Text(subject),
                        onPressed: () {
                          setState(() {
                            if (!_selectedSubjects.contains(subject)) {
                              _selectedSubjects.add(subject);
                            }
                          });
                        },
                      );
                    })
                    .toList(),
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(onPressed: _save, child: const Text('Save Changes')),
          ],
        ),
      ),
    );
  }

  IconData _getSourceIcon(SourceType type) {
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

  void _addSubject(String subject) {
    final trimmed = subject.trim();
    if (trimmed.isNotEmpty && !_selectedSubjects.contains(trimmed)) {
      setState(() {
        _selectedSubjects.add(trimmed);
        _subjectController.clear();
      });
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final updatedFact = Fact(
        id: widget.fact.id,
        content: _contentController.text.trim(),
        sourceId: _selectedSourceId,
        subjects: _selectedSubjects,
        imageUrl: widget.fact.imageUrl,
        ocrText: widget.fact.ocrText,
        createdAt: widget.fact.createdAt,
        updatedAt: DateTime.now(),
        // Preserve SRS data
        repetitions: widget.fact.repetitions,
        easeFactor: widget.fact.easeFactor,
        interval: widget.fact.interval,
        nextReviewAt: widget.fact.nextReviewAt,
        embedding: widget.fact.embedding,
      );

      await context.read<DataProvider>().updateFact(updatedFact);

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fact?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<DataProvider>().deleteFact(widget.fact.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close edit screen
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
