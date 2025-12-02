import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:mediapod_client/mediapod_client.dart';
import 'package:video_player/video_player.dart';

/// A video player widget for Mediapod assets
///
/// Supports HLS streaming for transcoded videos and direct playback
/// for source videos.
///
/// Example:
/// ```dart
/// MediapodVideoPlayer(
///   asset: videoAsset,
///   vodBaseUrl: 'https://vod.example.com',
///   autoPlay: true,
/// )
/// ```
class MediapodVideoPlayer extends StatefulWidget {
  /// The video asset to play
  final Asset asset;

  /// Base URL for VOD streaming (e.g., 'https://vod.example.com')
  final String vodBaseUrl;

  /// Whether to start playing automatically
  final bool autoPlay;

  /// Whether to loop the video
  final bool looping;

  /// Whether to show controls
  final bool showControls;

  /// Aspect ratio override (uses video's aspect ratio if null)
  final double? aspectRatio;

  /// Placeholder widget while loading
  final Widget? placeholder;

  /// Error widget when playback fails
  final Widget Function(BuildContext context, String error)? errorBuilder;

  /// Called when playback starts
  final VoidCallback? onPlay;

  /// Called when playback pauses
  final VoidCallback? onPause;

  /// Called when playback completes
  final VoidCallback? onComplete;

  /// Called when an error occurs
  final void Function(String error)? onError;

  /// Custom Chewie options
  final ChewieController Function(VideoPlayerController controller)?
      chewieControllerBuilder;

  const MediapodVideoPlayer({
    super.key,
    required this.asset,
    required this.vodBaseUrl,
    this.autoPlay = false,
    this.looping = false,
    this.showControls = true,
    this.aspectRatio,
    this.placeholder,
    this.errorBuilder,
    this.onPlay,
    this.onPause,
    this.onComplete,
    this.onError,
    this.chewieControllerBuilder,
  });

  @override
  State<MediapodVideoPlayer> createState() => _MediapodVideoPlayerState();
}

class _MediapodVideoPlayerState extends State<MediapodVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(MediapodVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _disposeControllers();
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isInitialized = false;
      _error = null;
    });

    try {
      final videoUrl = _getVideoUrl();

      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await _videoController!.initialize();

      // Listen for completion
      _videoController!.addListener(_onVideoStateChanged);

      // Create Chewie controller
      if (widget.chewieControllerBuilder != null) {
        _chewieController = widget.chewieControllerBuilder!(_videoController!);
      } else {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: widget.autoPlay,
          looping: widget.looping,
          showControls: widget.showControls,
          aspectRatio: widget.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return widget.errorBuilder?.call(context, errorMessage) ??
                _buildDefaultError(context, errorMessage);
          },
          placeholder: widget.placeholder,
          autoInitialize: true,
          allowFullScreen: true,
          allowMuting: true,
          allowPlaybackSpeedChanging: true,
          playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        );
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      final errorMsg = 'Failed to initialize video: $e';
      if (mounted) {
        setState(() {
          _error = errorMsg;
        });
      }
      widget.onError?.call(errorMsg);
    }
  }

  String _getVideoUrl() {
    // Check if HLS URL is available in asset URLs
    final hlsUrl = widget.asset.urls['hls'] as String?;
    if (hlsUrl != null) {
      debugPrint('[VideoPlayer] Using HLS URL from asset: $hlsUrl');
      return hlsUrl;
    }

    // Build HLS URL from VOD base URL and asset ID
    // Format: {vodBaseUrl}/{assetId}/hls/master.m3u8
    // The processor uploads HLS files to: media-vod/{assetId}/hls/
    final url = '${widget.vodBaseUrl}/${widget.asset.id}/hls/master.m3u8';
    debugPrint('[VideoPlayer] Built HLS URL: $url');
    debugPrint('[VideoPlayer] Asset URLs: ${widget.asset.urls}');
    return url;
  }

  void _onVideoStateChanged() {
    final controller = _videoController;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      widget.onPlay?.call();
    } else if (!controller.value.isPlaying &&
        controller.value.position > Duration.zero) {
      widget.onPause?.call();
    }

    // Check for completion
    if (controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ??
          _buildDefaultError(context, _error!);
    }

    if (!_isInitialized || _chewieController == null) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    return Chewie(controller: _chewieController!);
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildDefaultError(BuildContext context, String error) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to play video',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initializePlayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Play the video
  void play() {
    _videoController?.play();
  }

  /// Pause the video
  void pause() {
    _videoController?.pause();
  }

  /// Seek to a specific position
  void seekTo(Duration position) {
    _videoController?.seekTo(position);
  }

  /// Get current position
  Duration get position => _videoController?.value.position ?? Duration.zero;

  /// Get total duration
  Duration get duration => _videoController?.value.duration ?? Duration.zero;

  /// Check if video is playing
  bool get isPlaying => _videoController?.value.isPlaying ?? false;
}

/// A minimal video player without Chewie (lighter weight)
class MediapodVideoPlayerSimple extends StatefulWidget {
  final Asset asset;
  final String vodBaseUrl;
  final bool autoPlay;
  final bool looping;
  final BoxFit fit;

  const MediapodVideoPlayerSimple({
    super.key,
    required this.asset,
    required this.vodBaseUrl,
    this.autoPlay = false,
    this.looping = false,
    this.fit = BoxFit.contain,
  });

  @override
  State<MediapodVideoPlayerSimple> createState() =>
      _MediapodVideoPlayerSimpleState();
}

class _MediapodVideoPlayerSimpleState extends State<MediapodVideoPlayerSimple> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    // Build HLS URL from VOD base URL and asset ID
    // Format: {vodBaseUrl}/{assetId}/hls/master.m3u8
    final videoUrl = '${widget.vodBaseUrl}/${widget.asset.id}/hls/master.m3u8';

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

    await _controller.initialize();
    _controller.setLooping(widget.looping);

    if (widget.autoPlay) {
      _controller.play();
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        if (_controller.value.isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          if (!_controller.value.isPlaying)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
        ],
      ),
    );
  }
}
