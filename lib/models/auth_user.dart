class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.isPremium = false,
    this.isVerified = false,
    this.isGuest = false,
    this.createdAt,
    this.creatorScore = 0,
    this.challengesCompleted = 0,
    this.profileBadge,
  });

  final String id;
  final String email;
  final String name;
  final bool isPremium;
  final bool isVerified;
  final bool isGuest;
  final DateTime? createdAt;
  final int creatorScore;
  final int challengesCompleted;
  final String? profileBadge;

  AuthUser copyWith({
    String? id,
    String? email,
    String? name,
    bool? isPremium,
    bool? isVerified,
    bool? isGuest,
    DateTime? createdAt,
    int? creatorScore,
    int? challengesCompleted,
    String? profileBadge,
  }) =>
      AuthUser(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        isPremium: isPremium ?? this.isPremium,
        isVerified: isVerified ?? this.isVerified,
        isGuest: isGuest ?? this.isGuest,
        createdAt: createdAt ?? this.createdAt,
        creatorScore: creatorScore ?? this.creatorScore,
        challengesCompleted: challengesCompleted ?? this.challengesCompleted,
        profileBadge: profileBadge ?? this.profileBadge,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'is_premium': isPremium,
        'is_verified': isVerified,
        'is_guest': isGuest,
        'creator_score': creatorScore,
        'challenges_completed': challengesCompleted,
        if (profileBadge != null) 'profile_badge': profileBadge,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at'] ?? json['createdAt'];
    if (raw is String) {
      created = DateTime.tryParse(raw);
    }
    return AuthUser(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isPremium:
          (json['is_premium'] ?? json['premium'] ?? false) as bool? ?? false,
      isVerified: (json['is_verified'] ??
              json['verified'] ??
              json['email_verified'] ??
              false) as bool? ??
          false,
      isGuest: (json['is_guest'] ?? false) as bool? ?? false,
      createdAt: created,
      creatorScore: (json['creator_score'] as num?)?.toInt() ?? 0,
      challengesCompleted:
          (json['challenges_completed'] as num?)?.toInt() ?? 0,
      profileBadge: json['profile_badge'] as String?,
    );
  }
}
