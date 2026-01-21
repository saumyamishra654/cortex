import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fact.dart';
import '../providers/data_provider.dart';
import '../services/secure_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/embedding_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _openAiKeyController = TextEditingController();
  final _huggingFaceKeyController = TextEditingController();
  bool _isApiKeyVisible = false;
  bool _hasOpenAiKey = false;
  bool _hasHuggingFaceKey = false;
  EmbeddingProvider _selectedProvider = EmbeddingProvider.huggingface;
  bool _isLoading = true;
  bool _isGeneratingBatch = false;
  int _batchProgress = 0;
  int _batchTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final hasOpenAi = await SecureStorageService.hasOpenAiApiKey();
    final hasHuggingFace = await SecureStorageService.hasHuggingFaceApiKey();
    final provider = await SecureStorageService.getEmbeddingProvider();
    if (mounted) {
      setState(() {
        _hasOpenAiKey = hasOpenAi;
        _hasHuggingFaceKey = hasHuggingFace;
        _selectedProvider = provider;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _openAiKeyController.dispose();
    _huggingFaceKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    final user = FirebaseService.currentUser;
    final isSignedIn = FirebaseService.isSignedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account Section
          _SectionHeader(title: 'Account'),
          if (isSignedIn) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  (user?.email?.substring(0, 1) ?? 'U').toUpperCase(),
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              ),
              title: Text(user?.email ?? 'Signed In'),
              subtitle: const Text('Syncing to cloud'),
              trailing: TextButton(
                onPressed: _signOut,
                child: const Text('Sign Out'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Sync Now'),
              subtitle: const Text('Upload local data to cloud'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _syncToCloud(provider),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.cloud_off_rounded),
              title: const Text('Not signed in'),
              subtitle: const Text('Using local storage only'),
            ),
          ],
          const Divider(),

          // Appearance Section
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: Icon(
              widget.isDarkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
            ),
            title: const Text('Theme'),
            subtitle: Text(
              widget.isDarkMode ? 'Dark Mode (Tron)' : 'Light Mode (Sky)',
            ),
            trailing: Switch(
              value: widget.isDarkMode,
              onChanged: (_) => widget.onToggleTheme(),
            ),
            onTap: widget.onToggleTheme,
          ),
          const Divider(),

          // Embedding Provider Section
          _SectionHeader(title: 'Embedding Provider'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose how to generate semantic embeddings for finding related facts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Provider Selection
                _ProviderTile(
                  title: 'Hugging Face',
                  subtitle: 'Free • No credit card required',
                  icon: Icons.hub_rounded,
                  isSelected: _selectedProvider == EmbeddingProvider.huggingface,
                  isConfigured: _hasHuggingFaceKey,
                  onTap: () => _selectProvider(EmbeddingProvider.huggingface),
                ),
                const SizedBox(height: 8),
                _ProviderTile(
                  title: 'OpenAI',
                  subtitle: 'Paid • Higher quality embeddings',
                  icon: Icons.auto_awesome_rounded,
                  isSelected: _selectedProvider == EmbeddingProvider.openai,
                  isConfigured: _hasOpenAiKey,
                  onTap: () => _selectProvider(EmbeddingProvider.openai),
                ),
                
                const SizedBox(height: 16),
                
                // Info for web users about CORS proxy
                if (kIsWeb && _selectedProvider == EmbeddingProvider.huggingface)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Using CORS proxy for browser compatibility. If embedding fails, try again later or use OpenAI.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.blue.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // API Key Input for selected provider
                if (_selectedProvider == EmbeddingProvider.huggingface) ...[
                  _buildApiKeySection(
                    theme: theme,
                    title: 'Hugging Face Token',
                    hint: 'hf_...',
                    controller: _huggingFaceKeyController,
                    hasKey: _hasHuggingFaceKey,
                    onSave: _saveHuggingFaceKey,
                    onDelete: _deleteHuggingFaceKey,
                    helpText: 'Get a free token at huggingface.co → Settings → Access Tokens',
                  ),
                ] else ...[
                  _buildApiKeySection(
                    theme: theme,
                    title: 'OpenAI API Key',
                    hint: 'sk-...',
                    controller: _openAiKeyController,
                    hasKey: _hasOpenAiKey,
                    onSave: _saveOpenAiKey,
                    onDelete: _deleteOpenAiKey,
                    helpText: 'Requires paid OpenAI account',
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 32),

          // Statistics Section
          _SectionHeader(title: 'Statistics'),
          ListTile(
            leading: const Icon(Icons.library_books_rounded),
            title: const Text('Sources'),
            trailing: Text(
              '${provider.sources.length}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.note_rounded),
            title: const Text('Facts'),
            trailing: Text(
              '${provider.facts.length}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Due for Review'),
            trailing: Text(
              '${provider.dueFacts.length}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Fact Links'),
            trailing: Text(
              '${provider.factLinks.length}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 32),

          // Maintenance Section
          _SectionHeader(title: 'Maintenance'),
          ListTile(
            leading: const Icon(Icons.auto_fix_high_rounded),
            title: const Text('Generate All Embeddings'),
            subtitle: _isGeneratingBatch
                ? Text('Processing $_batchProgress of $_batchTotal...')
                : Text('${provider.facts.where((f) => f.embedding == null).length} facts without embeddings'),
            trailing: _isGeneratingBatch
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right_rounded),
            onTap: _isGeneratingBatch ? null : () => _generateAllEmbeddings(provider),
          ),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Refresh All Links'),
            subtitle: const Text('Rebuild [[wiki links]] from all facts'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _refreshLinks(provider),
          ),
          const Divider(height: 32),

          // About Section
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_rounded),
            title: const Text('Cortex'),
            subtitle: const Text('Version 0.1.0'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Your local data will remain on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseService.signOut();
    }
  }

  Future<void> _syncToCloud(DataProvider provider) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Syncing...')));

    try {
      await FirebaseService.syncToCloud(provider.sources, provider.facts);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sync complete!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
  }

  Future<void> _selectProvider(EmbeddingProvider provider) async {
    await SecureStorageService.saveEmbeddingProvider(provider);
    setState(() {
      _selectedProvider = provider;
    });
  }

  Widget _buildApiKeySection({
    required ThemeData theme,
    required String title,
    required String hint,
    required TextEditingController controller,
    required bool hasKey,
    required VoidCallback onSave,
    required VoidCallback onDelete,
    required String helpText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            if (!_isLoading && hasKey)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text('Configured', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          helpText,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: !_isApiKeyVisible,
                decoration: InputDecoration(
                  hintText: hasKey ? '************' : hint,
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_isApiKeyVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _isApiKeyVisible = !_isApiKeyVisible),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: onSave, child: const Text('Save')),
          ],
        ),
        if (hasKey) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Remove Token'),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  Future<void> _saveHuggingFaceKey() async {
    final key = _huggingFaceKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a token')),
      );
      return;
    }

    if (!key.startsWith('hf_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid token format. Should start with hf_')),
      );
      return;
    }

    await SecureStorageService.saveHuggingFaceApiKey(key);
    _huggingFaceKeyController.clear();
    setState(() => _hasHuggingFaceKey = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hugging Face token saved')),
      );
    }
  }

  Future<void> _deleteHuggingFaceKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Token?'),
        content: const Text('This will delete your saved Hugging Face token.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SecureStorageService.deleteHuggingFaceApiKey();
      setState(() => _hasHuggingFaceKey = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token removed')),
        );
      }
    }
  }

  Future<void> _saveOpenAiKey() async {
    final key = _openAiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key')),
      );
      return;
    }

    if (!key.startsWith('sk-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid API key format. Should start with sk-')),
      );
      return;
    }

    await SecureStorageService.saveOpenAiApiKey(key);
    _openAiKeyController.clear();
    setState(() => _hasOpenAiKey = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OpenAI API key saved')),
      );
    }
  }

  Future<void> _deleteOpenAiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove API Key?'),
        content: const Text('This will delete your saved OpenAI API key.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SecureStorageService.deleteOpenAiApiKey();
      setState(() => _hasOpenAiKey = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key removed')),
        );
      }
    }
  }

  Future<void> _refreshLinks(DataProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refresh Links?'),
        content: const Text(
          'This will rebuild all [[wiki links]] from your facts. Existing links will be recreated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Refreshing links...')));

      try {
        await provider.refreshAllLinks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Refreshed ${provider.factLinks.length} links'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _generateAllEmbeddings(DataProvider provider) async {
    final apiKey = await SecureStorageService.getActiveApiKey();
    if (apiKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please configure ${_selectedProvider == EmbeddingProvider.huggingface ? "Hugging Face" : "OpenAI"} API key first',
            ),
          ),
        );
      }
      return;
    }

    final factsWithoutEmbeddings = provider.facts.where((f) => f.embedding == null).toList();
    if (factsWithoutEmbeddings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All facts already have embeddings')),
        );
      }
      return;
    }

    setState(() {
      _isGeneratingBatch = true;
      _batchProgress = 0;
      _batchTotal = factsWithoutEmbeddings.length;
    });

    final embeddingService = EmbeddingService(apiKey: apiKey, provider: _selectedProvider);
    int successCount = 0;

    for (final fact in factsWithoutEmbeddings) {
      if (!mounted) break;

      try {
        final embedding = await embeddingService.generateEmbeddingWithContext(
          fact.content,
          fact.subjects,
        );
        if (embedding != null) {
          final updatedFact = Fact(
            id: fact.id,
            content: fact.content,
            sourceId: fact.sourceId,
            subjects: fact.subjects,
            imageUrl: fact.imageUrl,
            ocrText: fact.ocrText,
            createdAt: fact.createdAt,
            updatedAt: DateTime.now(),
            repetitions: fact.repetitions,
            easeFactor: fact.easeFactor,
            interval: fact.interval,
            nextReviewAt: fact.nextReviewAt,
            embedding: embedding,
          );
          await provider.updateFact(updatedFact);
          successCount++;
        }
      } catch (e) {
        debugPrint('Failed to generate embedding for fact ${fact.id}: $e');
      }

      if (mounted) {
        setState(() => _batchProgress++);
      }
      
      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      setState(() => _isGeneratingBatch = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated $successCount of ${factsWithoutEmbeddings.length} embeddings'),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isConfigured;
  final VoidCallback onTap;

  const _ProviderTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.isConfigured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected 
              ? theme.colorScheme.primary.withValues(alpha: 0.1) 
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isConfigured) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.radio_button_checked,
                color: theme.colorScheme.primary,
              )
            else
              Icon(
                Icons.radio_button_off,
                color: theme.colorScheme.outline,
              ),
          ],
        ),
      ),
    );
  }
}
