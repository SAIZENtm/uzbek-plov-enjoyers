import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced News Article Model with rich features
class NewsArticle {
  final String id;
  final String title;
  final String preview;
  final String content; // Supports markdown
  final String? imageUrl;
  final List<String> images; // Multiple images support
  final DateTime publishedAt;
  final DateTime? updatedAt;
  final bool isImportant;
  final bool isRead;
  final DateTime? readAt;
  
  // Enhanced categorization
  final NewsCategory category;
  final List<String> tags;
  final NewsPriority priority;
  
  // CTA (Call-to-Action) buttons
  final List<NewsAction> actions;
  
  // Audience targeting
  final List<String> targetBlocks; // ['A', 'B', 'C', etc.]
  final List<int> targetFloors; // [1, 2, 3, etc.]
  final bool isPublic; // Visible to all residents
  
  // Analytics and engagement
  final int viewCount;
  final int shareCount;
  final int reactionCount;
  final Map<String, int> reactions; // {'like': 15, 'heart': 3, etc.}
  
  // Metadata
  final String authorId;
  final String? authorName;
  final NewsStatus status;
  final DateTime? scheduledAt;
  final Map<String, dynamic> metadata; // Flexible additional data
  
  const NewsArticle({
    required this.id,
    required this.title,
    required this.preview,
    required this.content,
    this.imageUrl,
    this.images = const [],
    required this.publishedAt,
    this.updatedAt,
    this.isImportant = false,
    this.isRead = false,
    this.readAt,
    this.category = NewsCategory.general,
    this.tags = const [],
    this.priority = NewsPriority.normal,
    this.actions = const [],
    this.targetBlocks = const [],
    this.targetFloors = const [],
    this.isPublic = true,
    this.viewCount = 0,
    this.shareCount = 0,
    this.reactionCount = 0,
    this.reactions = const {},
    required this.authorId,
    this.authorName,
    this.status = NewsStatus.published,
    this.scheduledAt,
    this.metadata = const {},
  });

  /// Create from Firestore document
  factory NewsArticle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NewsArticle(
      id: doc.id,
      title: data['title'] ?? '',
      preview: data['preview'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      images: List<String>.from(data['images'] ?? []),
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isImportant: data['isImportant'] ?? false,
      isRead: data['isRead'] ?? false,
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      category: NewsCategory.fromString(data['category'] ?? 'general'),
      tags: List<String>.from(data['tags'] ?? []),
      priority: NewsPriority.fromString(data['priority'] ?? 'normal'),
      actions: (data['actions'] as List<dynamic>?)
          ?.map((action) => NewsAction.fromMap(action))
          .toList() ?? [],
      targetBlocks: List<String>.from(data['targetBlocks'] ?? []),
      targetFloors: List<int>.from(data['targetFloors'] ?? []),
      isPublic: data['isPublic'] ?? true,
      viewCount: data['viewCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      reactionCount: data['reactionCount'] ?? 0,
      reactions: Map<String, int>.from(data['reactions'] ?? {}),
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'],
      status: NewsStatus.fromString(data['status'] ?? 'published'),
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'preview': preview,
      'content': content,
      'imageUrl': imageUrl,
      'images': images,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isImportant': isImportant,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'category': category.value,
      'tags': tags,
      'priority': priority.value,
      'actions': actions.map((action) => action.toMap()).toList(),
      'targetBlocks': targetBlocks,
      'targetFloors': targetFloors,
      'isPublic': isPublic,
      'viewCount': viewCount,
      'shareCount': shareCount,
      'reactionCount': reactionCount,
      'reactions': reactions,
      'authorId': authorId,
      'authorName': authorName,
      'status': status.value,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'metadata': metadata,
    };
  }

  /// Create a copy with modified fields
  NewsArticle copyWith({
    String? id,
    String? title,
    String? preview,
    String? content,
    String? imageUrl,
    List<String>? images,
    DateTime? publishedAt,
    DateTime? updatedAt,
    bool? isImportant,
    bool? isRead,
    DateTime? readAt,
    NewsCategory? category,
    List<String>? tags,
    NewsPriority? priority,
    List<NewsAction>? actions,
    List<String>? targetBlocks,
    List<int>? targetFloors,
    bool? isPublic,
    int? viewCount,
    int? shareCount,
    int? reactionCount,
    Map<String, int>? reactions,
    String? authorId,
    String? authorName,
    NewsStatus? status,
    DateTime? scheduledAt,
    Map<String, dynamic>? metadata,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isImportant: isImportant ?? this.isImportant,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      actions: actions ?? this.actions,
      targetBlocks: targetBlocks ?? this.targetBlocks,
      targetFloors: targetFloors ?? this.targetFloors,
      isPublic: isPublic ?? this.isPublic,
      viewCount: viewCount ?? this.viewCount,
      shareCount: shareCount ?? this.shareCount,
      reactionCount: reactionCount ?? this.reactionCount,
      reactions: reactions ?? this.reactions,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Mark as read
  NewsArticle markAsRead() {
    return copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
  }

  /// Increment view count
  NewsArticle incrementViewCount() {
    return copyWith(viewCount: viewCount + 1);
  }

  /// Add reaction
  NewsArticle addReaction(String type) {
    final updatedReactions = Map<String, int>.from(reactions);
    updatedReactions[type] = (updatedReactions[type] ?? 0) + 1;
    
    return copyWith(
      reactions: updatedReactions,
      reactionCount: reactionCount + 1,
    );
  }

  /// Get formatted publish date
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);
    
    if (difference.inDays > 7) {
      return '${publishedAt.day}.${publishedAt.month.toString().padLeft(2, '0')}.${publishedAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} дн. назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин. назад';
    } else {
      return 'Только что';
    }
  }

  /// Get reading time estimate
  int get estimatedReadingTime {
    final wordCount = content.split(' ').length;
    return (wordCount / 200).ceil(); // Assume 200 words per minute
  }

  /// Check if this news is targeted to specific user
  bool isTargetedTo({
    required String userBlock,
    required int userFloor,
  }) {
    if (isPublic) return true;
    
    if (targetBlocks.isNotEmpty && !targetBlocks.contains(userBlock)) {
      return false;
    }
    
    if (targetFloors.isNotEmpty && !targetFloors.contains(userFloor)) {
      return false;
    }
    
    return true;
  }
}

/// News action (CTA button)
class NewsAction {
  final String id;
  final String label;
  final NewsActionType type;
  final String? url;
  final String? route;
  final Map<String, dynamic> parameters;
  final String? icon;
  final bool isPrimary;

  const NewsAction({
    required this.id,
    required this.label,
    required this.type,
    this.url,
    this.route,
    this.parameters = const {},
    this.icon,
    this.isPrimary = false,
  });

  factory NewsAction.fromMap(Map<String, dynamic> map) {
    return NewsAction(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      type: NewsActionType.fromString(map['type'] ?? 'external'),
      url: map['url'],
      route: map['route'],
      parameters: Map<String, dynamic>.from(map['parameters'] ?? {}),
      icon: map['icon'],
      isPrimary: map['isPrimary'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'type': type.value,
      'url': url,
      'route': route,
      'parameters': parameters,
      'icon': icon,
      'isPrimary': isPrimary,
    };
  }
}

/// News category enum
enum NewsCategory {
  general('general', 'Общие', '📢'),
  maintenance('maintenance', 'Обслуживание', '🔧'),
  events('events', 'Мероприятия', '🎉'),
  safety('safety', 'Безопасность', '🚨'),
  utilities('utilities', 'ЖКХ', '⚡'),
  community('community', 'Сообщество', '👥'),
  announcements('announcements', 'Объявления', '📋');

  const NewsCategory(this.value, this.displayName, this.emoji);
  
  final String value;
  final String displayName;
  final String emoji;

  static NewsCategory fromString(String value) {
    return NewsCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => NewsCategory.general,
    );
  }
}

/// News priority enum
enum NewsPriority {
  low('low', 'Низкий', 1),
  normal('normal', 'Обычный', 2),
  high('high', 'Высокий', 3),
  urgent('urgent', 'Срочный', 4);

  const NewsPriority(this.value, this.displayName, this.level);
  
  final String value;
  final String displayName;
  final int level;

  static NewsPriority fromString(String value) {
    return NewsPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => NewsPriority.normal,
    );
  }
}

/// News status enum
enum NewsStatus {
  draft('draft', 'Черновик'),
  scheduled('scheduled', 'Запланирован'),
  published('published', 'Опубликован'),
  archived('archived', 'Архивирован');

  const NewsStatus(this.value, this.displayName);
  
  final String value;
  final String displayName;

  static NewsStatus fromString(String value) {
    return NewsStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => NewsStatus.published,
    );
  }
}

/// News action type enum
enum NewsActionType {
  external('external', 'Внешняя ссылка'),
  internal('internal', 'Внутренняя навигация'),
  phone('phone', 'Телефон'),
  email('email', 'Email'),
  share('share', 'Поделиться');

  const NewsActionType(this.value, this.displayName);
  
  final String value;
  final String displayName;

  static NewsActionType fromString(String value) {
    return NewsActionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NewsActionType.external,
    );
  }
} 