import 'package:uuid/uuid.dart';

class Reminder {
  final String id;
  final String documentId;
  final DateTime actionableDate;
  final String contextReason;
  final int notifyDaysBefore;
  final bool isCompleted;
  final DateTime createdAt;

  Reminder({
    String? id,
    required this.documentId,
    required this.actionableDate,
    required this.contextReason,
    this.notifyDaysBefore = 0,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'actionableDate': actionableDate.toIso8601String(),
      'contextReason': contextReason,
      'notifyDaysBefore': notifyDaysBefore,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      documentId: map['documentId'],
      actionableDate: DateTime.parse(map['actionableDate']),
      contextReason: map['contextReason'],
      notifyDaysBefore: map['notifyDaysBefore'] as int,
      isCompleted: (map['isCompleted'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Reminder copyWith({
    String? id,
    String? documentId,
    DateTime? actionableDate,
    String? contextReason,
    int? notifyDaysBefore,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      actionableDate: actionableDate ?? this.actionableDate,
      contextReason: contextReason ?? this.contextReason,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
