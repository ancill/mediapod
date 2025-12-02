import 'package:flutter/widgets.dart';
import 'package:mediapod_client/mediapod_client.dart';

import '../controllers/media_controller.dart';
import '../models/media_config.dart';
import '../models/selection_state.dart';

/// InheritedWidget that provides media controller and signer to descendants
class MediapodProvider extends InheritedNotifier<MediaController> {
  /// The imgproxy signer for generating image URLs (optional)
  final ImgProxySigner? signer;

  /// Configuration for the media manager
  final MediaManagerConfig config;

  const MediapodProvider({
    super.key,
    required MediaController controller,
    this.signer,
    this.config = const MediaManagerConfig(),
    required super.child,
  }) : super(notifier: controller);

  /// Get the MediaController from context
  static MediaController controllerOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<MediapodProvider>();
    assert(provider != null, 'No MediapodProvider found in context');
    return provider!.notifier!;
  }

  /// Get the ImgProxySigner from context (may return null)
  static ImgProxySigner? signerOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<MediapodProvider>();
    assert(provider != null, 'No MediapodProvider found in context');
    return provider!.signer;
  }

  /// Get the MediaManagerConfig from context
  static MediaManagerConfig configOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<MediapodProvider>();
    assert(provider != null, 'No MediapodProvider found in context');
    return provider!.config;
  }

  /// Try to get the MediaController from context (returns null if not found)
  static MediaController? maybeControllerOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<MediapodProvider>();
    return provider?.notifier;
  }

  /// Try to get the ImgProxySigner from context (returns null if not found)
  static ImgProxySigner? maybeSignerOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<MediapodProvider>();
    return provider?.signer;
  }

  @override
  bool updateShouldNotify(MediapodProvider oldWidget) {
    return notifier != oldWidget.notifier ||
        signer != oldWidget.signer ||
        config != oldWidget.config;
  }
}

/// A convenience widget that creates and manages a MediaController
class MediapodScope extends StatefulWidget {
  /// The API client
  final MediapodClient client;

  /// The imgproxy signer (optional)
  final ImgProxySigner? signer;

  /// Configuration for the media manager
  final MediaManagerConfig config;

  /// Selection mode for the controller
  final SelectionMode selectionMode;

  /// Maximum selection count (0 = unlimited)
  final int maxSelectionCount;

  /// Whether to load assets on init
  final bool loadOnInit;

  /// Child widget
  final Widget child;

  const MediapodScope({
    super.key,
    required this.client,
    this.signer,
    this.config = const MediaManagerConfig(),
    this.selectionMode = SelectionMode.multiple,
    this.maxSelectionCount = 0,
    this.loadOnInit = true,
    required this.child,
  });

  @override
  State<MediapodScope> createState() => _MediapodScopeState();
}

class _MediapodScopeState extends State<MediapodScope> {
  late final MediaController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MediaController(
      client: widget.client,
      config: widget.config,
      selectionMode: widget.selectionMode,
      maxSelectionCount: widget.maxSelectionCount,
    );

    if (widget.loadOnInit) {
      _controller.loadAssets();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediapodProvider(
      controller: _controller,
      signer: widget.signer,
      config: widget.config,
      child: widget.child,
    );
  }
}

/// Extension methods for easy access to media provider
extension MediapodProviderExtension on BuildContext {
  /// Get the MediaController from this context
  MediaController get mediaController => MediapodProvider.controllerOf(this);

  /// Get the ImgProxySigner from this context (may return null)
  ImgProxySigner? get imgproxySigner => MediapodProvider.signerOf(this);

  /// Get the MediaManagerConfig from this context
  MediaManagerConfig get mediaConfig => MediapodProvider.configOf(this);

  /// Try to get the MediaController (returns null if not in provider)
  MediaController? get maybeMediaController =>
      MediapodProvider.maybeControllerOf(this);

  /// Try to get the ImgProxySigner (returns null if not in provider)
  ImgProxySigner? get maybeImgproxySigner =>
      MediapodProvider.maybeSignerOf(this);
}
