import 'package:uuid/uuid.dart';

class Document {
  final String id;
  final String title;
  final String category; // "Financial", "Medical", "Bills", "Other"
  final DateTime captureDate;
  final DateTime? letterDate;
  final String priority; // "Action Required", "Completed", "Informational"
  final String notes;
  final String imagePath;
  final String aiSummary;
  final List<String> aiTags;
  final DateTime? actionableDate;
  final String actionableDateContext;

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
    this.actionableDate,
    this.actionableDateContext = '',
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
      'actionableDate': actionableDate != null
          ? '${actionableDate!.year.toString().padLeft(4, '0')}-${actionableDate!.month.toString().padLeft(2, '0')}-${actionableDate!.day.toString().padLeft(2, '0')}'
          : null,
      'actionableDateContext': actionableDateContext,
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
      actionableDate: map['actionableDate'] != null
          ? DateTime.tryParse(map['actionableDate'])
          : null,
      actionableDateContext: map['actionableDateContext'] as String? ?? '',
    );
  }

  Document copyWith({
    String? id,
    String? title,
    String? category,
    DateTime? captureDate,
    DateTime? letterDate,
    String? priority,
    String? notes,
    String? imagePath,
    String? aiSummary,
    List<String>? aiTags,
    DateTime? actionableDate,
    bool clearActionableDate = false,
    String? actionableDateContext,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      captureDate: captureDate ?? this.captureDate,
      letterDate: letterDate ?? this.letterDate,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      aiSummary: aiSummary ?? this.aiSummary,
      aiTags: aiTags ?? this.aiTags,
      actionableDate: clearActionableDate ? null : (actionableDate ?? this.actionableDate),
      actionableDateContext: actionableDateContext ?? this.actionableDateContext,
    );
  }
}
