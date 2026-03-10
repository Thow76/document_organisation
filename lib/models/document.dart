import 'package:uuid/uuid.dart';

class Document {
  final String id;
  final String title;
  final String category; // "Banking", "Medical", "Other"
  final DateTime captureDate;
  final DateTime? letterDate;
  final String priority; // "Action Required", "Completed", "Informational"
  final String notes;
  final String imagePath;
  final String aiSummary;
  final List<String> aiTags;

  Document({
    String? id,
    required this.title,
    required this.category,
    required this.captureDate,
    this.letterDate,
    required this.priority,
    this.notes = '',
    required this.imagePath,
    this.aiSummary = '',
    List<String>? aiTags,
  }) : id = id ?? const Uuid().v4(),
       aiTags = aiTags ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'captureDate': captureDate.toIso8601String(),
      'letterDate': letterDate?.toIso8601String(),
      'priority': priority,
      'notes': notes,
      'imagePath': imagePath,
      'aiSummary': aiSummary,
      'aiTags': aiTags.join(','),
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'],
      title: map['title'],
      category: map['category'],
      captureDate: DateTime.parse(map['captureDate']),
      letterDate: map['letterDate'] != null
          ? DateTime.parse(map['letterDate'])
          : null,
      priority: map['priority'],
      notes: map['notes'] ?? '',
      imagePath: map['imagePath'],
      aiSummary: map['aiSummary'] ?? '',
      aiTags: (map['aiTags'] as String)
          .split(',')
          .where((tag) => tag.isNotEmpty)
          .toList(),
    );
  }
}
