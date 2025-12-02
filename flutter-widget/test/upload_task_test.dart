import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mediapod_flutter/mediapod_flutter.dart';

void main() {
  UploadTask createTestTask({
    String id = 'task-1',
    UploadStatus status = UploadStatus.queued,
    double progress = 0.0,
    String? assetId,
    Object? error,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return UploadTask(
      id: id,
      file: XFile('test.jpg'),
      kind: 'image',
      status: status,
      progress: progress,
      assetId: assetId,
      error: error,
      createdAt: createdAt ?? DateTime.now(),
      completedAt: completedAt,
      fileSize: 1024,
      mimeType: 'image/jpeg',
    );
  }

  group('UploadTask', () {
    test('creates with required values', () {
      final task = createTestTask();

      expect(task.id, 'task-1');
      expect(task.kind, 'image');
      expect(task.status, UploadStatus.queued);
      expect(task.progress, 0.0);
    });

    group('isActive', () {
      test('returns true when uploading', () {
        final task = createTestTask(status: UploadStatus.uploading);
        expect(task.isActive, isTrue);
      });

      test('returns true when processing', () {
        final task = createTestTask(status: UploadStatus.processing);
        expect(task.isActive, isTrue);
      });

      test('returns false when queued', () {
        final task = createTestTask(status: UploadStatus.queued);
        expect(task.isActive, isFalse);
      });

      test('returns false when completed', () {
        final task = createTestTask(status: UploadStatus.completed);
        expect(task.isActive, isFalse);
      });
    });

    group('canRetry', () {
      test('returns true when failed', () {
        final task = createTestTask(status: UploadStatus.failed);
        expect(task.canRetry, isTrue);
      });

      test('returns false when completed', () {
        final task = createTestTask(status: UploadStatus.completed);
        expect(task.canRetry, isFalse);
      });

      test('returns false when uploading', () {
        final task = createTestTask(status: UploadStatus.uploading);
        expect(task.canRetry, isFalse);
      });
    });

    group('canCancel', () {
      test('returns true when queued', () {
        final task = createTestTask(status: UploadStatus.queued);
        expect(task.canCancel, isTrue);
      });

      test('returns true when uploading', () {
        final task = createTestTask(status: UploadStatus.uploading);
        expect(task.canCancel, isTrue);
      });

      test('returns false when processing', () {
        final task = createTestTask(status: UploadStatus.processing);
        expect(task.canCancel, isFalse);
      });

      test('returns false when completed', () {
        final task = createTestTask(status: UploadStatus.completed);
        expect(task.canCancel, isFalse);
      });
    });

    group('isFinished', () {
      test('returns true when completed', () {
        final task = createTestTask(status: UploadStatus.completed);
        expect(task.isFinished, isTrue);
      });

      test('returns true when failed', () {
        final task = createTestTask(status: UploadStatus.failed);
        expect(task.isFinished, isTrue);
      });

      test('returns true when cancelled', () {
        final task = createTestTask(status: UploadStatus.cancelled);
        expect(task.isFinished, isTrue);
      });

      test('returns false when queued', () {
        final task = createTestTask(status: UploadStatus.queued);
        expect(task.isFinished, isFalse);
      });

      test('returns false when uploading', () {
        final task = createTestTask(status: UploadStatus.uploading);
        expect(task.isFinished, isFalse);
      });

      test('returns false when processing', () {
        final task = createTestTask(status: UploadStatus.processing);
        expect(task.isFinished, isFalse);
      });
    });

    group('elapsed', () {
      test('returns duration when completed', () {
        final createdAt = DateTime(2025, 1, 1, 10, 0, 0);
        final completedAt = DateTime(2025, 1, 1, 10, 0, 30);

        final task = createTestTask(
          createdAt: createdAt,
          completedAt: completedAt,
        );

        expect(task.elapsed, const Duration(seconds: 30));
      });

      test('returns null when not completed', () {
        final task = createTestTask();
        expect(task.elapsed, isNull);
      });
    });

    test('progressPercent returns formatted percentage', () {
      expect(createTestTask(progress: 0.0).progressPercent, '0%');
      expect(createTestTask(progress: 0.5).progressPercent, '50%');
      expect(createTestTask(progress: 1.0).progressPercent, '100%');
      expect(createTestTask(progress: 0.123).progressPercent, '12%');
    });

    test('copyWith creates new task with modified values', () {
      final original = createTestTask();
      final modified = original.copyWith(
        status: UploadStatus.uploading,
        progress: 0.5,
        assetId: 'asset-123',
      );

      expect(modified.status, UploadStatus.uploading);
      expect(modified.progress, 0.5);
      expect(modified.assetId, 'asset-123');
      // Unchanged values remain the same
      expect(modified.id, original.id);
      expect(modified.kind, original.kind);
    });

    test('equality based on id', () {
      final task1 = createTestTask(id: 'task-1');
      final task2 = createTestTask(id: 'task-1');
      final task3 = createTestTask(id: 'task-2');

      expect(task1, equals(task2));
      expect(task1, isNot(equals(task3)));
    });

    test('hashCode based on id', () {
      final task1 = createTestTask(id: 'task-1');
      final task2 = createTestTask(id: 'task-1');

      expect(task1.hashCode, task2.hashCode);
    });

    test('toString returns expected format', () {
      final task = createTestTask(
        id: 'task-1',
        status: UploadStatus.uploading,
        progress: 0.75,
      );

      expect(
        task.toString(),
        'UploadTask(id: task-1, status: UploadStatus.uploading, progress: 75%)',
      );
    });
  });

  group('UploadStatus', () {
    test('has all expected values', () {
      expect(
        UploadStatus.values,
        containsAll([
          UploadStatus.queued,
          UploadStatus.uploading,
          UploadStatus.processing,
          UploadStatus.completed,
          UploadStatus.failed,
          UploadStatus.cancelled,
        ]),
      );
    });
  });
}
