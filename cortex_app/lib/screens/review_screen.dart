import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fact.dart';
import '../providers/data_provider.dart';
import '../services/srs_service.dart';
import '../widgets/flashcard.dart';

enum ReviewMode { srs, shuffle }

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final SrsService _srsService = SrsService();
  List<Fact> _facts = [];
  int _currentIndex = 0;
  ReviewMode _mode = ReviewMode.shuffle; // Default to shuffle so cards always show
  String? _selectedTag;

  @override
  @override
  void initState() {
    super.initState();
    // Use post frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFacts();
    });
  }

  void _loadFacts() {
    final provider = context.read<DataProvider>();
    setState(() {
      List<Fact> facts;
      if (_mode == ReviewMode.srs) {
        facts = provider.dueFactsShuffled;
        // If no SRS cards, fall back to shuffle mode
        if (facts.isEmpty) {
          facts = provider.allFactsShuffled;
        }
      } else {
        facts = provider.allFactsShuffled;
      }
      
      // Filter by tag if selected
      if (_selectedTag != null) {
        facts = facts.where((f) => f.subjects.contains(_selectedTag)).toList();
      }
      
      _facts = facts;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    final allTags = provider.allSubjects;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedTag != null ? 'Review: $_selectedTag' : 'Review'),
        actions: [
          // Tag filter
          PopupMenuButton<String?>(
            icon: Badge(
              isLabelVisible: _selectedTag != null,
              child: const Icon(Icons.label_rounded),
            ),
            tooltip: 'Filter by Tag',
            onSelected: (tag) {
              setState(() {
                _selectedTag = tag;
              });
              _loadFacts();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      Icons.label_off_rounded,
                      color: _selectedTag == null 
                          ? theme.colorScheme.primary 
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('All Tags'),
                    if (_selectedTag == null) ...[
                      const Spacer(),
                      Icon(Icons.check, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
              ),
              if (allTags.isNotEmpty) const PopupMenuDivider(),
              ...allTags.map((tag) => PopupMenuItem(
                value: tag,
                child: Row(
                  children: [
                    Icon(
                      Icons.label_rounded,
                      color: _selectedTag == tag 
                          ? theme.colorScheme.primary 
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(tag),
                    if (_selectedTag == tag) ...[
                      const Spacer(),
                      Icon(Icons.check, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
              )),
            ],
          ),
          // Mode selector
          PopupMenuButton<ReviewMode>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Review Mode',
            onSelected: (mode) {
              setState(() {
                _mode = mode;
              });
              _loadFacts();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ReviewMode.srs,
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: _mode == ReviewMode.srs 
                          ? theme.colorScheme.primary 
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Spaced Repetition'),
                    if (_mode == ReviewMode.srs) ...[
                      const Spacer(),
                      Icon(Icons.check, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: ReviewMode.shuffle,
                child: Row(
                  children: [
                    Icon(
                      Icons.shuffle_rounded,
                      color: _mode == ReviewMode.shuffle 
                          ? theme.colorScheme.primary 
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Random Shuffle'),
                    if (_mode == ReviewMode.shuffle) ...[
                      const Spacer(),
                      Icon(Icons.check, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload Cards',
            onPressed: _loadFacts,
          ),
        ],
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(DataProvider provider) {
    final theme = Theme.of(context);
    
    // No facts at all in the app
    if (provider.facts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_add_rounded,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No facts yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add some facts to start reviewing',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    
    // No facts match current filter
    if (_facts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No matching facts',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTag != null 
                  ? 'No facts tagged "$_selectedTag"'
                  : 'Try a different filter',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedTag = null;
                });
                _loadFacts();
              },
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Clear Filter'),
            ),
          ],
        ),
      );
    }
    
    // Loop back to start when reaching end
    final effectiveIndex = _currentIndex % _facts.length;
    final fact = _facts[effectiveIndex];
    final source = provider.sources.firstWhere(
      (s) => s.id == fact.sourceId,
      orElse: () => provider.sources.first,
    );

    return Flashcard(
      fact: fact,
      sourceName: source.name,
      currentIndex: effectiveIndex,
      totalCount: _facts.length,
      onForgot: () => _handleReview(SrsService.qualityForgot),
      onSkip: () => _nextCard(),
      onGotIt: () => _handleReview(SrsService.qualityGood),
    );
  }

  void _handleReview(int quality) async {
    final effectiveIndex = _currentIndex % _facts.length;
    final fact = _facts[effectiveIndex];
    final updatedFact = _srsService.processReview(fact, quality);
    
    await context.read<DataProvider>().updateFact(updatedFact);
    
    _nextCard();
  }

  void _nextCard() {
    setState(() {
      _currentIndex++;
    });
  }
}
