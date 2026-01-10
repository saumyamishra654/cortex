import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../services/secure_storage_service.dart';

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
  final _apiKeyController = TextEditingController();
  bool _isApiKeyVisible = false;
  bool _hasApiKey = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  Future<void> _checkApiKey() async {
    final hasKey = await SecureStorageService.hasOpenAiApiKey();
    if (mounted) {
      setState(() {
        _hasApiKey = hasKey;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
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

          // API Configuration Section
          _SectionHeader(title: 'API Configuration'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'OpenAI API Key',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_isLoading && _hasApiKey)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Configured',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Required for embedding-based related facts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: !_isApiKeyVisible,
                        decoration: InputDecoration(
                          hintText: _hasApiKey ? '••••••••••••' : 'sk-...',
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isApiKeyVisible 
                                  ? Icons.visibility_off 
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isApiKeyVisible = !_isApiKeyVisible;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveApiKey,
                      child: const Text('Save'),
                    ),
                  ],
                ),
                if (_hasApiKey) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _deleteApiKey,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove API Key'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 20,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'API key is stored in your device\'s secure storage (Keychain on iOS/macOS, encrypted storage on Android).',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
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
          const Divider(height: 32),

          // Account Section (placeholder for future)
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.login_rounded),
            title: const Text('Sign In'),
            subtitle: const Text('Sync your data across devices'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sign in coming soon!'),
                ),
              );
            },
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

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API key'),
        ),
      );
      return;
    }
    
    // Basic validation
    if (!key.startsWith('sk-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid API key format'),
        ),
      );
      return;
    }
    
    await SecureStorageService.saveOpenAiApiKey(key);
    _apiKeyController.clear();
    
    setState(() {
      _hasApiKey = true;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key saved securely'),
        ),
      );
    }
  }

  Future<void> _deleteApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove API Key?'),
        content: const Text(
          'This will delete your saved API key. You\'ll need to enter it again to use embedding features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await SecureStorageService.deleteOpenAiApiKey();
      setState(() {
        _hasApiKey = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key removed'),
          ),
        );
      }
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
