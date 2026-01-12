import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Embedding provider options
enum EmbeddingProvider {
  openai,
  huggingface,
}

/// Service for securely storing sensitive data like API keys
/// Uses platform-native secure storage:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences or Keystore
/// - macOS: Keychain
/// - Web: LocalStorage (less secure, consider alternatives for production)
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  
  // Keys
  static const _openAiApiKey = 'openai_api_key';
  static const _huggingFaceApiKey = 'huggingface_api_key';
  static const _embeddingProvider = 'embedding_provider';
  
  // OpenAI API Key
  static Future<void> saveOpenAiApiKey(String apiKey) async {
    await _storage.write(key: _openAiApiKey, value: apiKey);
  }
  
  static Future<String?> getOpenAiApiKey() async {
    return await _storage.read(key: _openAiApiKey);
  }
  
  static Future<void> deleteOpenAiApiKey() async {
    await _storage.delete(key: _openAiApiKey);
  }
  
  static Future<bool> hasOpenAiApiKey() async {
    final key = await getOpenAiApiKey();
    return key != null && key.isNotEmpty;
  }
  
  // Hugging Face API Key
  static Future<void> saveHuggingFaceApiKey(String apiKey) async {
    await _storage.write(key: _huggingFaceApiKey, value: apiKey);
  }
  
  static Future<String?> getHuggingFaceApiKey() async {
    return await _storage.read(key: _huggingFaceApiKey);
  }
  
  static Future<void> deleteHuggingFaceApiKey() async {
    await _storage.delete(key: _huggingFaceApiKey);
  }
  
  static Future<bool> hasHuggingFaceApiKey() async {
    final key = await getHuggingFaceApiKey();
    return key != null && key.isNotEmpty;
  }
  
  // Embedding Provider Preference
  static Future<void> saveEmbeddingProvider(EmbeddingProvider provider) async {
    await _storage.write(key: _embeddingProvider, value: provider.name);
  }
  
  static Future<EmbeddingProvider> getEmbeddingProvider() async {
    final value = await _storage.read(key: _embeddingProvider);
    if (value == 'openai') return EmbeddingProvider.openai;
    return EmbeddingProvider.huggingface; // Default to free option
  }
  
  /// Get the API key for the current provider
  static Future<String?> getActiveApiKey() async {
    final provider = await getEmbeddingProvider();
    switch (provider) {
      case EmbeddingProvider.openai:
        return getOpenAiApiKey();
      case EmbeddingProvider.huggingface:
        return getHuggingFaceApiKey();
    }
  }
  
  /// Check if the active provider has an API key configured
  static Future<bool> hasActiveApiKey() async {
    final provider = await getEmbeddingProvider();
    switch (provider) {
      case EmbeddingProvider.openai:
        return hasOpenAiApiKey();
      case EmbeddingProvider.huggingface:
        return hasHuggingFaceApiKey();
    }
  }
  
  /// Delete all stored secrets
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

// SECURE API KEY HANDLING BEST PRACTICES:
//
// 1. NEVER commit API keys to source control
//    - Add .env to .gitignore
//    - Use environment variables in CI/CD
//
// 2. USE PLATFORM-NATIVE SECURE STORAGE
//    - iOS/macOS: Keychain (encrypted, hardware-backed on newer devices)
//    - Android: EncryptedSharedPreferences or Android Keystore
//    - Web: Consider server-side proxy instead of storing keys client-side
//
// 3. FOR PRODUCTION APPS:
//    - Use a backend proxy to make API calls (keys never leave your server)
//    - If client-side keys are required, use short-lived tokens
//    - Implement certificate pinning for API requests
//    - Consider obfuscation for release builds
//
// 4. USER-PROVIDED KEYS (like in this app):
//    - Use flutter_secure_storage (this implementation)
//    - Never log or display the full key
//    - Provide clear UI feedback when key is saved/valid
//
// 5. GITIGNORE ENTRIES:
//    .env
//    secrets.dart
