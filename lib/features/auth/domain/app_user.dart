import 'dart:convert';

class AppUser {
  final String id;
  final String displayName;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.displayName,
    required this.createdAt,
  });

  AppUser copyWith({String? displayName}) => AppUser(
        id: id,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String encode() => jsonEncode(toJson());
  static AppUser decode(String raw) =>
      AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
