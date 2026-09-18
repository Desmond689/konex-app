import 'package:equatable/equatable.dart';

class ReportEntity extends Equatable {
  const ReportEntity({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.details,
    this.status = 'open',
    required this.createdAt,
    this.reporterUsername,
  });

  final String id;
  final String reporterId;
  final String targetType;
  final String targetId;
  final String reason;
  final String? details;
  final String status;
  final DateTime createdAt;
  final String? reporterUsername;

  factory ReportEntity.fromMap(Map<String, dynamic> m) {
    final reporter = m['profiles'] as Map<String, dynamic>?;
    return ReportEntity(
      id: m['id'] as String,
      reporterId: m['reporter_id'] as String,
      targetType: m['target_type'] as String,
      targetId: m['target_id'] as String,
      reason: m['reason'] as String? ?? '',
      details: m['details'] as String?,
      status: m['status'] as String? ?? 'open',
      createdAt: DateTime.parse(m['created_at'] as String),
      reporterUsername: reporter?['username'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, status];
}

class AuditLogEntity extends Equatable {
  const AuditLogEntity({
    required this.id,
    this.actorId,
    required this.action,
    this.targetType,
    this.targetId,
    this.reason,
    required this.createdAt,
  });

  final String id;
  final String? actorId;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? reason;
  final DateTime createdAt;

  factory AuditLogEntity.fromMap(Map<String, dynamic> m) {
    return AuditLogEntity(
      id: m['id'] as String,
      actorId: m['actor_id'] as String?,
      action: m['action'] as String,
      targetType: m['target_type'] as String?,
      targetId: m['target_id'] as String?,
      reason: m['reason'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id];
}

class AdminStats extends Equatable {
  const AdminStats({
    this.totalUsers = 0,
    this.openReports = 0,
    this.totalPosts = 0,
    this.totalSquads = 0,
  });

  final int totalUsers;
  final int openReports;
  final int totalPosts;
  final int totalSquads;

  @override
  List<Object?> get props => [totalUsers, openReports, totalPosts, totalSquads];
}
