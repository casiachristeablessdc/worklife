import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklife/models/activity_model.dart';

void main() {
  group('ActivityModel', () {
    test('reads and writes the Firestore activity fields', () {
      final createdAt = DateTime(2026, 10, 13, 9);
      final model = ActivityModel.fromMap('activity-1', {
        'title': 'Pickleball',
        'category': 'Leisure',
        'notes': 'With Haro',
        'date': '2026-10-13',
        'durationMinutes': 60,
        'completed': true,
        'createdAt': Timestamp.fromDate(createdAt),
      });

      expect(model.id, 'activity-1');
      expect(model.title, 'Pickleball');
      expect(model.category, 'Leisure');
      expect(model.notes, 'With Haro');
      expect(model.date, DateTime(2026, 10, 13));
      expect(model.durationMinutes, 60);
      expect(model.completed, isTrue);
      expect(model.createdAt, createdAt);

      final saved = model.toMap();
      expect(saved['title'], 'Pickleball');
      expect(saved['category'], 'Leisure');
      expect(saved['notes'], 'With Haro');
      expect(saved['date'], '2026-10-13');
      expect(saved['durationMinutes'], 60);
      expect(saved['completed'], isTrue);
    });

    test('defaults malformed optional values safely', () {
      final model = ActivityModel.fromMap('activity-2', {
        'title': 'Walk',
        'durationMinutes': 'unknown',
        'completed': 'yes',
      });

      expect(model.title, 'Walk');
      expect(model.category, 'Personal');
      expect(model.notes, isEmpty);
      expect(model.durationMinutes, 0);
      expect(model.completed, isFalse);
    });
  });
}
