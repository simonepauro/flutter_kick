import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/apple_developer_credentials.dart';

const String _kPrefsKey = 'apple_developer_credentials';

/// Provider per le credenziali Apple Developer (persistite in SharedPreferences).
final appleDeveloperCredentialsProvider =
    NotifierProvider<AppleDeveloperCredentialsNotifier, AsyncValue<AppleDeveloperCredentials?>>(
  AppleDeveloperCredentialsNotifier.new,
);

class AppleDeveloperCredentialsNotifier extends Notifier<AsyncValue<AppleDeveloperCredentials?>> {
  @override
  AsyncValue<AppleDeveloperCredentials?> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kPrefsKey);
      AppleDeveloperCredentials? creds;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>?;
        creds = AppleDeveloperCredentials.fromJson(map);
      }
      state = AsyncValue.data(creds);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(AppleDeveloperCredentials credentials) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(credentials.toJson()));
      state = AsyncValue.data(credentials);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefsKey);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
