import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'auth_service.dart';

/// Wraps `/api/profile/*` for both the user's own profile editing and
/// fetching anyone else's public profile.
class ProfileService {
  ProfileService._();
  static final ProfileService _instance = ProfileService._();
  factory ProfileService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 25);

  final http.Client _client = http.Client();

  Map<String, String> get _authHeaders {
    final t = AuthService().token;
    return {
      if (t != null) 'authorization': 'Bearer $t',
      'content-type': 'application/json',
    };
  }

  /// Upload (or replace) the signed-in user's avatar. Accepts raw
  /// bytes + a hint at the source extension so we can guess the
  /// content type. Returns the new `avatar_url` from the server.
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = AuthService().token;
    if (token == null) {
      throw const ProfileError('Sign in to upload an avatar.');
    }
    final lower = filename.toLowerCase();
    MediaType mime;
    if (lower.endsWith('.png')) {
      mime = MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      mime = MediaType('image', 'webp');
    } else {
      mime = MediaType('image', 'jpeg');
    }
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/profile/avatar'),
    )
      ..headers['authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: mime,
      ));
    final streamed = await req.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ProfileError(_extractDetail(res));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final url = body['avatar_url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ProfileError('Server returned no avatar URL.');
    }
    return url;
  }

  /// Update bio and/or wellbeing visibility. Returns the server
  /// payload — including `{saved:false, reason}` when AI moderation
  /// rejected the bio.
  Future<Map<String, dynamic>> update({
    String? bio,
    bool? showWellbeingPublic,
  }) async {
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    if (showWellbeingPublic != null) {
      body['show_wellbeing_public'] = showWellbeingPublic;
    }
    final res = await _client
        .post(Uri.parse('$_baseUrl/profile/update'),
            headers: _authHeaders, body: jsonEncode(body))
        .timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ProfileError(_extractDetail(res));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<PublicProfile> fetchPublic(int userId) async {
    final res = await _client
        .get(Uri.parse('$_baseUrl/profile/$userId'), headers: _authHeaders)
        .timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ProfileError(_extractDetail(res));
    }
    return PublicProfile.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  String _extractDetail(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] is String) {
        return body['detail'] as String;
      }
    } catch (_) {}
    debugPrint('[Profile] HTTP ${res.statusCode}: ${res.body}');
    return 'Something went wrong (${res.statusCode}).';
  }
}

class ProfileError implements Exception {
  const ProfileError(this.message);
  final String message;
  @override
  String toString() => 'ProfileError($message)';
}

class WellbeingSnapshot {
  const WellbeingSnapshot({
    required this.avgMood,
    required this.checkinCount,
    required this.windowDays,
  });
  final double avgMood;
  final int checkinCount;
  final int windowDays;

  factory WellbeingSnapshot.fromJson(Map<String, dynamic> json) =>
      WellbeingSnapshot(
        avgMood: ((json['avg_mood'] as num?) ?? 0).toDouble(),
        checkinCount: (json['checkin_count'] as num?)?.toInt() ?? 0,
        windowDays: (json['window_days'] as num?)?.toInt() ?? 7,
      );
}

class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.profileBadge,
    required this.creatorScore,
    required this.challengesCompleted,
    required this.streak,
    required this.joinedAt,
    required this.wellbeing,
  });

  final int id;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final String? profileBadge;
  final int creatorScore;
  final int challengesCompleted;
  final int streak;
  final DateTime? joinedAt;
  final WellbeingSnapshot? wellbeing;

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        id: (json['id'] as num).toInt(),
        name: (json['name'] as String?) ?? 'Anonymous',
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        profileBadge: json['profile_badge'] as String?,
        creatorScore: (json['creator_score'] as num?)?.toInt() ?? 0,
        challengesCompleted:
            (json['challenges_completed'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        joinedAt: json['joined_at'] is String
            ? DateTime.tryParse(json['joined_at'] as String)
            : null,
        wellbeing: json['wellbeing'] is Map
            ? WellbeingSnapshot.fromJson(
                (json['wellbeing'] as Map).cast<String, dynamic>())
            : null,
      );

  /// Absolute URL for the avatar image — backend stores it as
  /// `/api/avatars/<file>`, prepend the host for the image widget.
  String? avatarAbsoluteUrl({String host = 'https://mood8.app'}) {
    final u = avatarUrl;
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('http')) return u;
    return '$host$u';
  }
}
