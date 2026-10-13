import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String title;
  final String category;
  final String notes;
  final DateTime date;
  final int durationMinutes;
  final bool completed;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.category,
    required this.notes,
    required this.date,
    required this.durationMinutes,
    required this.completed,
    required this.createdAt,
    this.updatedAt,
  });

  factory ActivityModel.fromMap(String id, Map<String, dynamic> map) {
    return ActivityModel(
      id: id,
      title: _readString(map['title'], fallback: ''),
      category: _readString(map['category'], fallback: 'Personal'),
      notes: _readString(map['notes'], fallback: ''),
      date: _readDate(map['date']) ?? DateTime.now(),
      durationMinutes: _readInt(map['durationMinutes']),
      completed: map['completed'] is bool ? map['completed'] as bool : false,
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'notes': notes,
      'date': _dateKey(date),
      'durationMinutes': durationMinutes,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  ActivityModel copyWith({
    String? title,
    String? category,
    String? notes,
    DateTime? date,
    int? durationMinutes,
    bool? completed,
    DateTime? updatedAt,
  }) {
    return ActivityModel(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      completed: completed ?? this.completed,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return 0;
  }

  static String _readString(dynamic value, {required String fallback}) {
    return value is String ? value : fallback;
  }

  static String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
