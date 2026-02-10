/// 앱 내 알림 타입
enum NotificationType {
  deadline,   // 마감 임박 알림
  newNotice,  // 새 공지사항 알림
  system,     // 시스템 알림
}

/// 앱 내 알림 모델
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? noticeId; // 연결된 공지사항 ID (있는 경우)
  final Map<String, dynamic>? payload; // 추가 데이터

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.noticeId,
    this.payload,
  });

  /// 읽음 상태 변경된 새 인스턴스 반환
  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? noticeId,
    Map<String, dynamic>? payload,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      noticeId: noticeId ?? this.noticeId,
      payload: payload ?? this.payload,
    );
  }

  /// JSON으로 변환 (SharedPreferences 저장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.index,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'noticeId': noticeId,
      'payload': payload,
    };
  }

  /// JSON에서 생성 (SharedPreferences 로컬 저장용)
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values[json['type'] as int],
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      noticeId: json['noticeId'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  /// 백엔드 notification_logs 응답에서 생성
  factory AppNotification.fromBackendJson(Map<String, dynamic> json) {
    // notification_type → NotificationType 변환
    NotificationType type;
    switch (json['notification_type'] as String? ?? 'new_notice') {
      case 'deadline':
        type = NotificationType.deadline;
        break;
      case 'system':
        type = NotificationType.system;
        break;
      default:
        type = NotificationType.newNotice;
    }

    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '공지사항',
      body: json['body'] as String? ?? '',
      type: type,
      createdAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
      noticeId: json['notice_id'] as String?,
    );
  }

  /// 알림 타입별 아이콘 데이터
  String get iconName {
    switch (type) {
      case NotificationType.deadline:
        return 'calendar_today';
      case NotificationType.newNotice:
        return 'notifications';
      case NotificationType.system:
        return 'info';
    }
  }

  /// 알림 타입별 표시 텍스트
  String get typeDisplayText {
    switch (type) {
      case NotificationType.deadline:
        return '마감 임박';
      case NotificationType.newNotice:
        return '새 공지';
      case NotificationType.system:
        return '시스템';
    }
  }

  /// 상대적 시간 표시 (예: "3시간 전", "2일 전")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${createdAt.month}/${createdAt.day}';
    }
  }
}
