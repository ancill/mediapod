import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mediapod_client/mediapod_client.dart';

import '../models/media_config.dart';
import '../models/selection_state.dart';
import '../models/upload_task.dart';
import 'upload_controller.dart';

/// Main controller for media management
///
/// Manages assets, selection state, and coordinates uploads
class MediaController extends ChangeNotifier {
  final MediapodClient client;
  final MediaManagerConfig config;
  final UploadController uploadController;

  List<Asset> _assets = [];
  SelectionState _selection;
  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  int _total = 0;

  StreamSubscription<UploadTask>? _uploadSubscription;
  final Map<String, Timer> _processingPollers = {};
  bool _isDisposed = false;

  /// All loaded assets
  List<Asset> get assets => List.unmodifiable(_assets);

  /// Current selection state
  SelectionState get selection => _selection;

  /// Whether assets are being loaded
  bool get isLoading => _isLoading;

  /// Error message if load failed
  String? get error => _error;

  /// Whether there are more assets to load
  bool get hasMore => _hasMore;

  /// Total number of assets on server
  int get total => _total;

  /// Upload queue tasks
  List<UploadTask> get uploadQueue => uploadController.pendingTasks;

  /// Whether there are active uploads
  bool get hasActiveUploads => uploadController.hasActiveUploads;

  /// Number of selected assets
  int get selectedCount => _selection.count;

  /// Whether any assets are selected
  bool get hasSelection => _selection.hasSelection;

  /// Get selected assets
  List<Asset> get selectedAssets => _selection.getSelectedAssets(_assets);

  MediaController({
    required this.client,
    this.config = const MediaManagerConfig(),
    UploadController? uploadController,
    SelectionMode selectionMode = SelectionMode.multiple,
    int maxSelectionCount = 0,
  })  : uploadController = uploadController ??
            UploadController(
              client: client,
              maxConcurrentUploads: config.maxConcurrentUploads,
            ),
        _selection = SelectionState(
          mode: selectionMode,
          maxCount: maxSelectionCount,
        ) {
    _setupUploadListener();
  }

  void _setupUploadListener() {
    _uploadSubscription = uploadController.taskUpdates.listen((task) {
      if (task.status == UploadStatus.completed && task.assetId != null) {
        // Reload the completed asset and add to list
        _loadCompletedAsset(task.assetId!);
      }
      notifyListeners();
    });
  }

  Future<void> _loadCompletedAsset(String assetId) async {
    try {
      final asset = await client.getAsset(assetId: assetId);
      // Insert at the beginning of the list
      _assets.insert(0, asset);
      _total++;
      notifyListeners();

      // If video is still processing, start polling for updates
      if (asset.kind == 'video' && asset.isProcessing) {
        _startProcessingPoller(assetId);
      }
    } catch (e) {
      // Silently fail, asset will appear on next refresh
      debugPrint('Failed to load completed asset: $e');
    }
  }

  /// Start polling for asset processing completion
  void _startProcessingPoller(String assetId) {
    // Cancel any existing poller for this asset
    _processingPollers[assetId]?.cancel();

    // Poll every 3 seconds
    _processingPollers[assetId] = Timer.periodic(
      const Duration(seconds: 3),
      (timer) async {
        // Stop if controller is disposed
        if (_isDisposed) {
          timer.cancel();
          return;
        }

        try {
          final asset = await client.getAsset(assetId: assetId);

          // Check again after async call
          if (_isDisposed) {
            timer.cancel();
            return;
          }

          // Update the asset in the list
          final index = _assets.indexWhere((a) => a.id == assetId);
          if (index != -1) {
            _assets[index] = asset;
            notifyListeners();
          }

          // Stop polling if asset is ready or failed
          if (asset.isReady || asset.isFailed) {
            timer.cancel();
            _processingPollers.remove(assetId);
            debugPrint('Asset $assetId processing complete: ${asset.state}');
          }
        } catch (e) {
          debugPrint('Failed to poll asset $assetId: $e');
          // Stop polling on error after a few retries
          timer.cancel();
          _processingPollers.remove(assetId);
        }
      },
    );
  }

  /// Load assets from server
  Future<void> loadAssets() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await client.listAssets();
      _assets = response.assets;
      _total = response.total;
      _hasMore = _assets.length < _total;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh assets (reload from server)
  Future<void> refreshAssets() async {
    _assets = [];
    _hasMore = true;
    await loadAssets();
  }

  /// Delete an asset
  Future<void> deleteAsset(String assetId) async {
    try {
      await client.deleteAsset(assetId: assetId);
      _assets.removeWhere((a) => a.id == assetId);
      _selection = _selection.deselect(assetId);
      _total--;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete all selected assets
  Future<void> deleteSelected() async {
    final idsToDelete = List<String>.from(_selection.selectedIds);

    for (final id in idsToDelete) {
      try {
        await deleteAsset(id);
      } catch (e) {
        // Continue deleting others
        debugPrint('Failed to delete asset $id: $e');
      }
    }
  }

  /// Toggle selection of an asset
  void toggleSelection(String assetId) {
    _selection = _selection.toggle(assetId);
    notifyListeners();
  }

  /// Select an asset
  void selectAsset(String assetId) {
    _selection = _selection.select(assetId);
    notifyListeners();
  }

  /// Deselect an asset
  void deselectAsset(String assetId) {
    _selection = _selection.deselect(assetId);
    notifyListeners();
  }

  /// Select all loaded assets
  void selectAll() {
    _selection = _selection.selectAll(_assets);
    notifyListeners();
  }

  /// Clear all selections
  void clearSelection() {
    _selection = _selection.clear();
    notifyListeners();
  }

  /// Check if an asset is selected
  bool isSelected(String assetId) => _selection.isSelected(assetId);

  /// Add files to upload queue
  Future<List<UploadTask>> queueUploads(
    List<XFile> files, {
    AssetKind? kind,
  }) async {
    final tasks = await uploadController.enqueueAll(files, kind: kind);
    notifyListeners();
    return tasks;
  }

  /// Add a single file to upload queue
  Future<UploadTask> queueUpload(
    XFile file, {
    AssetKind? kind,
  }) async {
    final task = await uploadController.enqueue(file, kind: kind);
    notifyListeners();
    return task;
  }

  /// Cancel an upload
  void cancelUpload(String taskId) {
    uploadController.cancel(taskId);
    notifyListeners();
  }

  /// Retry a failed upload
  Future<void> retryUpload(String taskId) async {
    await uploadController.retry(taskId);
    notifyListeners();
  }

  /// Clear upload history
  void clearUploadHistory() {
    uploadController.clearHistory();
    notifyListeners();
  }

  /// Update selection mode
  void setSelectionMode(SelectionMode mode) {
    if (_selection.mode == mode) return;
    _selection = SelectionState(
      mode: mode,
      maxCount: _selection.maxCount,
    );
    notifyListeners();
  }

  /// Find an asset by ID
  Asset? findAsset(String assetId) {
    try {
      return _assets.firstWhere((a) => a.id == assetId);
    } catch (_) {
      return null;
    }
  }

  /// Get asset at index
  Asset? assetAt(int index) {
    if (index < 0 || index >= _assets.length) return null;
    return _assets[index];
  }

  @override
  void dispose() {
    _isDisposed = true;
    _uploadSubscription?.cancel();
    // Cancel all processing pollers
    for (final timer in _processingPollers.values) {
      timer.cancel();
    }
    _processingPollers.clear();
    uploadController.dispose();
    super.dispose();
  }
}
