import 'package:mediapod_client/mediapod_client.dart';

/// Selection mode for asset grid
enum SelectionMode {
  /// No selection allowed
  none,

  /// Single asset selection
  single,

  /// Multiple asset selection
  multiple,
}

/// Manages selection state for assets
class SelectionState {
  /// Currently selected asset IDs
  final Set<String> selectedIds;

  /// Selection mode
  final SelectionMode mode;

  /// Maximum number of selections (0 = unlimited)
  final int maxCount;

  const SelectionState({
    this.selectedIds = const {},
    this.mode = SelectionMode.multiple,
    this.maxCount = 0,
  });

  /// Whether any assets are selected
  bool get hasSelection => selectedIds.isNotEmpty;

  /// Number of selected assets
  int get count => selectedIds.length;

  /// Whether selection limit is reached
  bool get isAtLimit => maxCount > 0 && selectedIds.length >= maxCount;

  /// Whether a specific asset is selected
  bool isSelected(String assetId) => selectedIds.contains(assetId);

  /// Check if an asset can be selected
  bool canSelect(String assetId) {
    if (mode == SelectionMode.none) return false;
    if (isSelected(assetId)) return true; // Can always deselect
    if (mode == SelectionMode.single) return true; // Will replace
    return !isAtLimit;
  }

  /// Toggle selection of an asset
  SelectionState toggle(String assetId) {
    if (mode == SelectionMode.none) return this;

    if (mode == SelectionMode.single) {
      if (isSelected(assetId)) {
        return copyWith(selectedIds: {});
      }
      return copyWith(selectedIds: {assetId});
    }

    // Multiple selection
    final newIds = Set<String>.from(selectedIds);
    if (newIds.contains(assetId)) {
      newIds.remove(assetId);
    } else if (!isAtLimit) {
      newIds.add(assetId);
    }
    return copyWith(selectedIds: newIds);
  }

  /// Select an asset
  SelectionState select(String assetId) {
    if (mode == SelectionMode.none) return this;
    if (isSelected(assetId)) return this;

    if (mode == SelectionMode.single) {
      return copyWith(selectedIds: {assetId});
    }

    if (isAtLimit) return this;
    return copyWith(selectedIds: {...selectedIds, assetId});
  }

  /// Deselect an asset
  SelectionState deselect(String assetId) {
    if (!isSelected(assetId)) return this;
    final newIds = Set<String>.from(selectedIds)..remove(assetId);
    return copyWith(selectedIds: newIds);
  }

  /// Select all assets from a list
  SelectionState selectAll(List<Asset> assets) {
    if (mode != SelectionMode.multiple) return this;

    final newIds = <String>{};
    for (final asset in assets) {
      if (maxCount > 0 && newIds.length >= maxCount) break;
      newIds.add(asset.id);
    }
    return copyWith(selectedIds: newIds);
  }

  /// Clear all selections
  SelectionState clear() {
    if (selectedIds.isEmpty) return this;
    return copyWith(selectedIds: {});
  }

  /// Get selected assets from a list
  List<Asset> getSelectedAssets(List<Asset> assets) {
    return assets.where((a) => selectedIds.contains(a.id)).toList();
  }

  SelectionState copyWith({
    Set<String>? selectedIds,
    SelectionMode? mode,
    int? maxCount,
  }) {
    return SelectionState(
      selectedIds: selectedIds ?? this.selectedIds,
      mode: mode ?? this.mode,
      maxCount: maxCount ?? this.maxCount,
    );
  }

  @override
  String toString() {
    return 'SelectionState(count: $count, mode: $mode, maxCount: $maxCount)';
  }
}
