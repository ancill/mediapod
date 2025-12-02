import 'package:flutter_test/flutter_test.dart';
import 'package:mediapod_flutter/mediapod_flutter.dart';

void main() {
  Asset createTestAsset(String id) {
    return Asset(
      id: id,
      kind: 'image',
      state: 'ready',
      filename: 'test.jpg',
      mimeType: 'image/jpeg',
      size: 1024,
      bucket: 'media-originals',
      objectKey: '2025/01/01/$id.jpg',
      createdAt: DateTime.now(),
      urls: {},
    );
  }

  group('SelectionState', () {
    test('creates with default values', () {
      const state = SelectionState();

      expect(state.selectedIds, isEmpty);
      expect(state.mode, SelectionMode.multiple);
      expect(state.maxCount, 0);
      expect(state.hasSelection, isFalse);
      expect(state.count, 0);
    });

    test('isSelected returns correct value', () {
      const state = SelectionState(selectedIds: {'id1', 'id2'});

      expect(state.isSelected('id1'), isTrue);
      expect(state.isSelected('id2'), isTrue);
      expect(state.isSelected('id3'), isFalse);
    });

    test('isAtLimit returns correct value', () {
      const noLimit = SelectionState(selectedIds: {'id1', 'id2'}, maxCount: 0);
      expect(noLimit.isAtLimit, isFalse);

      const atLimit = SelectionState(selectedIds: {'id1', 'id2'}, maxCount: 2);
      expect(atLimit.isAtLimit, isTrue);

      const belowLimit =
          SelectionState(selectedIds: {'id1', 'id2'}, maxCount: 3);
      expect(belowLimit.isAtLimit, isFalse);
    });

    group('toggle', () {
      test('adds unselected asset in multiple mode', () {
        const state = SelectionState(selectedIds: {'id1'});
        final newState = state.toggle('id2');

        expect(newState.selectedIds, containsAll(['id1', 'id2']));
      });

      test('removes selected asset in multiple mode', () {
        const state = SelectionState(selectedIds: {'id1', 'id2'});
        final newState = state.toggle('id1');

        expect(newState.selectedIds, equals({'id2'}));
      });

      test('replaces selection in single mode', () {
        const state = SelectionState(
          selectedIds: {'id1'},
          mode: SelectionMode.single,
        );
        final newState = state.toggle('id2');

        expect(newState.selectedIds, equals({'id2'}));
      });

      test('clears selection when toggling selected in single mode', () {
        const state = SelectionState(
          selectedIds: {'id1'},
          mode: SelectionMode.single,
        );
        final newState = state.toggle('id1');

        expect(newState.selectedIds, isEmpty);
      });

      test('does nothing in none mode', () {
        const state = SelectionState(mode: SelectionMode.none);
        final newState = state.toggle('id1');

        expect(newState.selectedIds, isEmpty);
      });

      test('respects max count limit', () {
        const state = SelectionState(
          selectedIds: {'id1', 'id2'},
          maxCount: 2,
        );
        final newState = state.toggle('id3');

        expect(newState.selectedIds, equals({'id1', 'id2'}));
      });

      test('allows deselection when at limit', () {
        const state = SelectionState(
          selectedIds: {'id1', 'id2'},
          maxCount: 2,
        );
        final newState = state.toggle('id1');

        expect(newState.selectedIds, equals({'id2'}));
      });
    });

    group('select', () {
      test('adds asset to selection', () {
        const state = SelectionState();
        final newState = state.select('id1');

        expect(newState.selectedIds, contains('id1'));
      });

      test('does not duplicate already selected asset', () {
        const state = SelectionState(selectedIds: {'id1'});
        final newState = state.select('id1');

        expect(newState.selectedIds.length, 1);
        expect(identical(newState, state), isTrue);
      });

      test('replaces selection in single mode', () {
        const state = SelectionState(
          selectedIds: {'id1'},
          mode: SelectionMode.single,
        );
        final newState = state.select('id2');

        expect(newState.selectedIds, equals({'id2'}));
      });

      test('does nothing in none mode', () {
        const state = SelectionState(mode: SelectionMode.none);
        final newState = state.select('id1');

        expect(newState.selectedIds, isEmpty);
      });

      test('does nothing when at limit', () {
        const state = SelectionState(
          selectedIds: {'id1', 'id2'},
          maxCount: 2,
        );
        final newState = state.select('id3');

        expect(newState.selectedIds.length, 2);
      });
    });

    group('deselect', () {
      test('removes asset from selection', () {
        const state = SelectionState(selectedIds: {'id1', 'id2'});
        final newState = state.deselect('id1');

        expect(newState.selectedIds, equals({'id2'}));
      });

      test('does nothing for unselected asset', () {
        const state = SelectionState(selectedIds: {'id1'});
        final newState = state.deselect('id2');

        expect(identical(newState, state), isTrue);
      });
    });

    group('selectAll', () {
      test('selects all assets in multiple mode', () {
        final assets = [
          createTestAsset('id1'),
          createTestAsset('id2'),
          createTestAsset('id3'),
        ];

        const state = SelectionState();
        final newState = state.selectAll(assets);

        expect(newState.selectedIds, containsAll(['id1', 'id2', 'id3']));
      });

      test('respects max count when selecting all', () {
        final assets = [
          createTestAsset('id1'),
          createTestAsset('id2'),
          createTestAsset('id3'),
        ];

        const state = SelectionState(maxCount: 2);
        final newState = state.selectAll(assets);

        expect(newState.selectedIds.length, 2);
      });

      test('does nothing in single mode', () {
        final assets = [
          createTestAsset('id1'),
          createTestAsset('id2'),
        ];

        const state = SelectionState(mode: SelectionMode.single);
        final newState = state.selectAll(assets);

        expect(identical(newState, state), isTrue);
      });
    });

    group('clear', () {
      test('removes all selections', () {
        const state = SelectionState(selectedIds: {'id1', 'id2'});
        final newState = state.clear();

        expect(newState.selectedIds, isEmpty);
      });

      test('returns same state if already empty', () {
        const state = SelectionState();
        final newState = state.clear();

        expect(identical(newState, state), isTrue);
      });
    });

    group('getSelectedAssets', () {
      test('returns list of selected assets', () {
        final assets = [
          createTestAsset('id1'),
          createTestAsset('id2'),
          createTestAsset('id3'),
        ];

        const state = SelectionState(selectedIds: {'id1', 'id3'});
        final selected = state.getSelectedAssets(assets);

        expect(selected.length, 2);
        expect(selected.map((a) => a.id), containsAll(['id1', 'id3']));
      });

      test('returns empty list when nothing selected', () {
        final assets = [createTestAsset('id1')];
        const state = SelectionState();
        final selected = state.getSelectedAssets(assets);

        expect(selected, isEmpty);
      });
    });

    group('canSelect', () {
      test('returns false in none mode', () {
        const state = SelectionState(mode: SelectionMode.none);

        expect(state.canSelect('id1'), isFalse);
      });

      test('returns true for already selected (allows deselect)', () {
        const state = SelectionState(
          selectedIds: {'id1', 'id2'},
          maxCount: 2,
        );

        expect(state.canSelect('id1'), isTrue);
      });

      test('returns true in single mode', () {
        const state = SelectionState(mode: SelectionMode.single);

        expect(state.canSelect('id1'), isTrue);
      });

      test('returns false when at limit in multiple mode', () {
        const state = SelectionState(
          selectedIds: {'id1', 'id2'},
          maxCount: 2,
        );

        expect(state.canSelect('id3'), isFalse);
      });

      test('returns true when not at limit in multiple mode', () {
        const state = SelectionState(
          selectedIds: {'id1'},
          maxCount: 2,
        );

        expect(state.canSelect('id2'), isTrue);
      });
    });

    test('copyWith creates new state with modified values', () {
      const state = SelectionState(
        selectedIds: {'id1'},
        mode: SelectionMode.multiple,
        maxCount: 5,
      );

      final modified = state.copyWith(
        selectedIds: {'id2'},
        mode: SelectionMode.single,
      );

      expect(modified.selectedIds, equals({'id2'}));
      expect(modified.mode, SelectionMode.single);
      expect(modified.maxCount, 5); // unchanged
    });

    test('toString returns expected format', () {
      const state = SelectionState(
        selectedIds: {'id1', 'id2'},
        mode: SelectionMode.multiple,
        maxCount: 5,
      );

      expect(
        state.toString(),
        'SelectionState(count: 2, mode: SelectionMode.multiple, maxCount: 5)',
      );
    });
  });
}
