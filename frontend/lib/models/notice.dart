/// 공지사항 모델 클래스
class Notice {
  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime date;
  final String? url;
  final bool isNew;
  final int views;
  final List<String> tags;
  final bool isBookmarked;
  final DateTime? deadline; // 마감일 (있는 경우)

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.date,
    this.url,
    this.isNew = false,
    this.views = 0,
    this.tags = const [],
    this.isBookmarked = false,
    this.deadline,
  });

  /// JSON에서 Notice 객체 생성
  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      url: json['url'] as String?,
      isNew: json['is_new'] as bool? ?? false,
      views: json['views'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
    );
  }

  /// Notice 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'date': date.toIso8601String(),
      'url': url,
      'is_new': isNew,
      'views': views,
      'tags': tags,
      'is_bookmarked': isBookmarked,
      'deadline': deadline?.toIso8601String(),
    };
  }

  /// 공지사항 복사 (일부 필드 수정용)
  Notice copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    DateTime? date,
    String? url,
    bool? isNew,
    int? views,
    List<String>? tags,
    bool? isBookmarked,
    DateTime? deadline,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      date: date ?? this.date,
      url: url ?? this.url,
      isNew: isNew ?? this.isNew,
      views: views ?? this.views,
      tags: tags ?? this.tags,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      deadline: deadline ?? this.deadline,
    );
  }

  /// 날짜 포맷팅 (yyyy.MM.dd)
  String get formattedDate {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  /// 마감일까지 남은 일수 (있는 경우)
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    final now = DateTime.now();
    final difference = deadline!.difference(now);
    return difference.inDays;
  }

  /// 마감 임박 여부 (3일 이내)
  bool get isDeadlineSoon {
    final days = daysUntilDeadline;
    return days != null && days >= 0 && days <= 3;
  }
}
