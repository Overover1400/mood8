import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/user_profile.dart';
import 'database_service.dart';
import 'sync_service.dart';

class UserRepository {
  UserRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  static const String userKey = 'me';

  final DatabaseService _db;

  Box<UserProfile> get _box => _db.userBox;

  UserProfile? getCurrentUser() => _box.get(userKey);

  Future<void> saveUser(UserProfile profile) async {
    try {
      profile.updatedAt = DateTime.now();
      await _box.put(userKey, profile);
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('UserRepository.saveUser failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      await SyncService().recordTombstone('user_profile', userKey);
      await _box.delete(userKey);
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('UserRepository.clear failed: $e\n$st');
      rethrow;
    }
  }

  bool isOnboardingComplete() {
    final user = getCurrentUser();
    return user?.hasCompletedOnboarding ?? false;
  }

  ValueListenable<Box<UserProfile>> watchUser() => _box.listenable();
}
