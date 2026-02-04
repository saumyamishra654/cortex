import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../models/source.dart';
import '../models/fact.dart';
import 'source_detail_screen.dart';
import 'fact_detail_screen.dart'; // Assuming this exists or will be used for facts

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  late TabController _tabController;
  
  String _query = '';
  List<Source> _sourceResults = [];
  List<Fact> _factResults = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _query = _searchController.text;
    });
    _performSearch();
  }
  
  void _performSearch() {
    if (_query.isEmpty) {
      setState(() {
        _sourceResults = [];
        _factResults = [];
      });
      return;
    }
    
    final provider = context.read<DataProvider>();
    setState(() {
      _sourceResults = provider.searchSources(_query);
      _factResults = provider.searchFacts(_query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResults = _sourceResults.isNotEmpty || _factResults.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Search...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
          ),
          style: theme.textTheme.titleLarge,
          textInputAction: TextInputAction.search,
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Sources'),
            Tab(text: 'Facts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllResultsTab(theme),
          _buildSourcesTab(theme),
          _buildFactsTab(theme),
        ],
      ),
    );
  }
  
  Widget _buildAllResultsTab(ThemeData theme) {
    if (_query.isEmpty) {
      return _buildEmptyState(theme, 'Type to search sources and facts');
    }
    
    if (_sourceResults.isEmpty && _factResults.isEmpty) {
      return _buildEmptyState(theme, 'No results found');
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_sourceResults.isNotEmpty) ...[
          Text(
            'SOURCES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._sourceResults.take(3).map((s) => _SourceResultTile(source: s)),
          if (_sourceResults.length > 3)
             TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('See all sources'),
            ),
          const SizedBox(height: 24),
        ],
        
        if (_factResults.isNotEmpty) ...[
          Text(
            'FACTS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._factResults.take(5).map((f) => _FactResultTile(fact: f)),
           if (_factResults.length > 5)
             TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: const Text('See all facts'),
            ),
        ],
      ],
    );
  }
  
  Widget _buildSourcesTab(ThemeData theme) {
     if (_query.isEmpty) {
      return _buildEmptyState(theme, 'Search for books, articles, etc.');
    }
    
    if (_sourceResults.isEmpty) {
      return _buildEmptyState(theme, 'No matching sources');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sourceResults.length,
      itemBuilder: (context, index) {
        return _SourceResultTile(source: _sourceResults[index]);
      },
    );
  }
  
  Widget _buildFactsTab(ThemeData theme) {
    if (_query.isEmpty) {
      return _buildEmptyState(theme, 'Search for specific facts');
    }
    
    if (_factResults.isEmpty) {
      return _buildEmptyState(theme, 'No matching facts');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _factResults.length,
      itemBuilder: (context, index) {
        return _FactResultTile(fact: _factResults[index]);
      },
    );
  }
  
  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 64,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceResultTile extends StatelessWidget {
  final Source source;
  
  const _SourceResultTile({required this.source});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getSourceIcon(source.type),
            color: theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          source.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: source.defaultTags.isNotEmpty 
            ? Text(
                source.defaultTags.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SourceDetailScreen(source: source),
            ),
          );
        },
      ),
    );
  }
  
  IconData _getSourceIcon(SourceType type) {
    switch (type) {
      case SourceType.book: return Icons.book;
      case SourceType.article: return Icons.article;
      case SourceType.podcast: return Icons.podcasts;
      case SourceType.video: return Icons.video_library;
      default: return Icons.folder;
    }
  }
}

class _FactResultTile extends StatelessWidget {
  final Fact fact;
  
  const _FactResultTile({required this.fact});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
               builder: (_) => FactDetailScreen(fact: fact),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fact.displayText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              if (fact.subjects.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: fact.subjects.take(3).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$tag',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
