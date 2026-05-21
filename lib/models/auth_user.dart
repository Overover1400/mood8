class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.isPremium = false,
    this.isVerified = false,
    this.isGuest = false,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final bool isPremium;
  final bool isVerified;
  final bool isGuest;
  final DateTime? createdAt;

  AuthUser copyWith({
    String? id,
    String? email,
    String? name,
    bool? isPremium,
    bool? isVerified,
    bool? isGuest,
    DateTime? createdAt,
  }) =>
      AuthUser(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        isPremium: isPremium ?? this.isPremium,
        isVerified: isVerified ?? this.isVerified,
        isGuest: isGuest ?? this.isGuest,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'is_premium': isPremium,
        'is_verified': isVerified,
        'is_guest': isGuest,
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
    );
  }
}
