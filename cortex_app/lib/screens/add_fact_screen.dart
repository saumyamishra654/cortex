import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';

class AddFactScreen extends StatefulWidget {
  final Source source;

  const AddFactScreen({super.key, required this.source});

  @override
  State<AddFactScreen> createState() => _AddFactScreenState();
}

class _AddFactScreenState extends State<AddFactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _subjectController = TextEditingController();
  List<String> _selectedSubjects = [];

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
      appBar: AppBar(title: const Text('New Fact')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Source indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.source_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Adding to: ${widget.source.name}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content input
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: 'Fact',
                hintText: 'Enter a single fact or idea...',
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
              autofocus: true,
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
            ElevatedButton(onPressed: _submit, child: const Text('Save Fact')),
          ],
        ),
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

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      await context.read<DataProvider>().addFact(
        content: _contentController.text.trim(),
        sourceId: widget.source.id,
        subjects: _selectedSubjects.isNotEmpty ? _selectedSubjects : null,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
