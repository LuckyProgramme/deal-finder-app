import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> removeAll();
}

final class SecureCredentials implements CredentialStore {
  const SecureCredentials([this.storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage storage;
  @override
  Future<String?> read(String key) => storage.read(key: 'deal_finder.$key');
  @override
  Future<void> write(String key, String value) => value.isEmpty
      ? storage.delete(key: 'deal_finder.$key')
      : storage.write(key: 'deal_finder.$key', value: value);
  @override
  Future<void> removeAll() async {
    for (final key in [
      'geminiKey',
      'geminiModel',
      'serviceAccount',
      'spreadsheetId',
      'postRunSync',
    ]) {
      await storage.delete(key: 'deal_finder.$key');
    }
  }
}
