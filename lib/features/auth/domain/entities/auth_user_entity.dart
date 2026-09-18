import 'package:equatable/equatable.dart';

class AuthUserEntity extends Equatable {
  const AuthUserEntity({
    required this.id,
    required this.email,
    this.username,
    this.gamerName,
    this.phone,
    this.avatarUrl,
    this.country,
    this.playerType,
    this.onboardingCompleted = false,
  });

  final String id;
  final String email;
  final String? username;
  final String? gamerName;
  final String? phone;
  final String? avatarUrl;
  final String? country;
  final String? playerType;
  final bool onboardingCompleted;

  @override
  List<Object?> get props => [
        id,
        email,
        username,
        gamerName,
        phone,
        avatarUrl,
        country,
        playerType,
        onboardingCompleted,
      ];
}
