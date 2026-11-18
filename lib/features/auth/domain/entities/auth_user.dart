class AuthUser {
  final int id;
  final String name;
  final String? email;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num).toInt(),
    name: (json['name'] ?? '') as String,
    email: json['email'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar_url': avatarUrl,
  };
}
