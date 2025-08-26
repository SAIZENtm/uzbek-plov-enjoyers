import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a community news article.
///
/// This model is deliberately kept plain-dart with only
/// serialization helpers so it can be reused in
/// services, widgets and tests without Flutter imports.
class NewsArticle {
  final String id;
  final String title;
  final String preview;
  final String content;
  final String? imageUrl;
  final DateTime publishedAt;
  final bool isImportant;
  
  // CTA functionality
  final List<String> ctaLabels;
  final List<String> ctaLinks;
  final String? ctaType; // 'external' | 'internal'
  
  // Read tracking
  final bool isRead;
  final DateTime? readAt;
  
  // Targeting
  final bool isPublic;
  final List<String> targetBlocks;
  final List<String> targetFloors;
  
  // Publishing
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final String status; // 'draft', 'scheduled', 'published', 'expired'
  
  // Metadata
  final String? authorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.preview,
    required this.content,
    this.imageUrl,
    required this.publishedAt,
    this.isImportant = false,
    this.ctaLabels = const [],
    this.ctaLinks = const [],
    this.ctaType,
    this.isRead = false,
    this.readAt,
    this.isPublic = true,
    this.targetBlocks = const [],
    this.targetFloors = const [],
    this.scheduledAt,
    this.expiresAt,
    this.status = 'published',
    this.authorId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory to build from JSON (e.g. remote REST or Firestore map)
  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse a date from Firestore Timestamp or ISO8601 String
    DateTime parseDate(dynamic dateValue, {bool isRequired = true}) {
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      if (isRequired) {
        // Return current time as a fallback for required fields
        return DateTime.now();
      }
      // This part of the conditional is unreachable given the isRequired check,
      // but it's good practice to handle all paths.
      // A non-nullable value is expected.
      throw ArgumentError('Invalid or null date value');
    }

    DateTime? parseNullableDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      return null;
    }

    return NewsArticle(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      publishedAt: parseDate(json['publishedAt']),
      isImportant: json['isImportant'] as bool? ?? false,
      ctaLabels: List<String>.from(json['ctaLabels'] as List? ?? []),
      ctaLinks: List<String>.from(json['ctaLinks'] as List? ?? []),
      ctaType: json['ctaType'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      readAt: parseNullableDate(json['readAt']),
      isPublic: json['isPublic'] as bool? ?? true,
      targetBlocks: List<String>.from(json['targetBlocks'] as List? ?? []),
      targetFloors: List<String>.from(json['targetFloors'] as List? ?? []),
      scheduledAt: parseNullableDate(json['scheduledAt']),
      expiresAt: parseNullableDate(json['expiresAt']),
      status: json['status'] as String? ?? 'published',
      authorId: json['authorId'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'preview': preview,
      'content': content,
      'imageUrl': imageUrl,
      'publishedAt': publishedAt.toIso8601String(),
      'isImportant': isImportant,
      'ctaLabels': ctaLabels,
      'ctaLinks': ctaLinks,
      'ctaType': ctaType,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'isPublic': isPublic,
      'targetBlocks': targetBlocks,
      'targetFloors': targetFloors,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'status': status,
      'authorId': authorId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get hasCtaButtons => ctaLabels.isNotEmpty && ctaLinks.isNotEmpty;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isScheduled => status == 'scheduled' && scheduledAt != null && DateTime.now().isBefore(scheduledAt!);
  bool get shouldShow => status == 'published' && !isExpired && !isScheduled;

  // Copy with method for immutable updates
  NewsArticle copyWith({
    String? id,
    String? title,
    String? preview,
    String? content,
    String? imageUrl,
    DateTime? publishedAt,
    bool? isImportant,
    List<String>? ctaLabels,
    List<String>? ctaLinks,
    String? ctaType,
    bool? isRead,
    DateTime? readAt,
    bool? isPublic,
    List<String>? targetBlocks,
    List<String>? targetFloors,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    String? status,
    String? authorId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      isImportant: isImportant ?? this.isImportant,
      ctaLabels: ctaLabels ?? this.ctaLabels,
      ctaLinks: ctaLinks ?? this.ctaLinks,
      ctaType: ctaType ?? this.ctaType,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isPublic: isPublic ?? this.isPublic,
      targetBlocks: targetBlocks ?? this.targetBlocks,
      targetFloors: targetFloors ?? this.targetFloors,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 