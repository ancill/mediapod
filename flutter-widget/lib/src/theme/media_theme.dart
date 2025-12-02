import 'package:flutter/material.dart';

/// Theme configuration for Mediapod widgets
///
/// Provides comprehensive theming options for all media components.
///
/// Example:
/// ```dart
/// MediapodMediaManager(
///   theme: MediaTheme(
///     primaryColor: Colors.blue,
///     tileBorderRadius: BorderRadius.circular(8),
///   ),
///   // ...
/// )
/// ```
class MediaTheme {
  // Colors
  /// Primary color used for selection, progress, and accents
  final Color primaryColor;

  /// Background color for surfaces
  final Color backgroundColor;

  /// Surface color for cards and overlays
  final Color surfaceColor;

  /// Error color for error states
  final Color errorColor;

  /// Progress bar color
  final Color progressColor;

  /// Processing indicator color
  final Color processingColor;

  /// Overlay color for dark overlays
  final Color overlayColor;

  /// Selection indicator color
  final Color selectionColor;

  // Typography
  /// Title text style
  final TextStyle? titleStyle;

  /// Subtitle text style
  final TextStyle? subtitleStyle;

  /// Caption text style
  final TextStyle? captionStyle;

  /// Badge text style (e.g., duration badge on videos)
  final TextStyle? badgeStyle;

  // Shapes
  /// Border radius for asset tiles
  final BorderRadius tileBorderRadius;

  /// Border radius for buttons
  final BorderRadius buttonBorderRadius;

  /// Border radius for dialogs and bottom sheets
  final BorderRadius dialogBorderRadius;

  // Sizing
  /// Spacing between grid items
  final double gridSpacing;

  /// Aspect ratio for asset tiles
  final double tileAspectRatio;

  /// Default icon size
  final double iconSize;

  /// Size of selection indicator
  final double selectionIndicatorSize;

  /// Thickness of selection border
  final double selectionBorderWidth;

  // Animations
  /// Default animation duration
  final Duration animationDuration;

  /// Default animation curve
  final Curve animationCurve;

  // Overlays
  /// Opacity for overlay backgrounds
  final double overlayOpacity;

  /// Gradient for top/bottom bars in fullscreen
  final LinearGradient? overlayGradient;

  // Custom builders
  /// Custom progress indicator builder
  final Widget Function(BuildContext context, double progress)? progressBuilder;

  /// Custom empty state builder
  final Widget Function(BuildContext context)? emptyStateBuilder;

  /// Custom error state builder
  final Widget Function(BuildContext context, String error)? errorBuilder;

  /// Custom loading indicator builder
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Custom processing overlay builder
  final Widget Function(BuildContext context)? processingOverlayBuilder;

  const MediaTheme({
    // Colors
    this.primaryColor = Colors.blue,
    this.backgroundColor = Colors.white,
    this.surfaceColor = Colors.white,
    this.errorColor = Colors.red,
    this.progressColor = Colors.blue,
    this.processingColor = Colors.white,
    this.overlayColor = Colors.black,
    this.selectionColor = Colors.blue,

    // Typography
    this.titleStyle,
    this.subtitleStyle,
    this.captionStyle,
    this.badgeStyle,

    // Shapes
    this.tileBorderRadius = const BorderRadius.all(Radius.circular(4)),
    this.buttonBorderRadius = const BorderRadius.all(Radius.circular(8)),
    this.dialogBorderRadius = const BorderRadius.all(Radius.circular(16)),

    // Sizing
    this.gridSpacing = 4.0,
    this.tileAspectRatio = 1.0,
    this.iconSize = 24.0,
    this.selectionIndicatorSize = 24.0,
    this.selectionBorderWidth = 2.0,

    // Animations
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeInOut,

    // Overlays
    this.overlayOpacity = 0.7,
    this.overlayGradient,

    // Custom builders
    this.progressBuilder,
    this.emptyStateBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.processingOverlayBuilder,
  });

  /// Create a theme from a Flutter ThemeData
  factory MediaTheme.fromTheme(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return MediaTheme(
      primaryColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      surfaceColor: colorScheme.surface,
      errorColor: colorScheme.error,
      progressColor: colorScheme.primary,
      processingColor: colorScheme.onSurface,
      overlayColor: colorScheme.scrim,
      selectionColor: colorScheme.primary,
      titleStyle: theme.textTheme.titleMedium,
      subtitleStyle: theme.textTheme.bodyMedium,
      captionStyle: theme.textTheme.bodySmall,
      badgeStyle: theme.textTheme.labelSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Create a dark theme
  factory MediaTheme.dark() {
    return MediaTheme(
      primaryColor: Colors.blue.shade400,
      backgroundColor: Colors.grey.shade900,
      surfaceColor: Colors.grey.shade800,
      errorColor: Colors.red.shade400,
      progressColor: Colors.blue.shade400,
      processingColor: Colors.white,
      overlayColor: Colors.black,
      selectionColor: Colors.blue.shade400,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      subtitleStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 14,
      ),
      captionStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
      ),
      badgeStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Create a light theme
  factory MediaTheme.light() {
    return MediaTheme(
      primaryColor: Colors.blue,
      backgroundColor: Colors.white,
      surfaceColor: Colors.grey.shade100,
      errorColor: Colors.red,
      progressColor: Colors.blue,
      processingColor: Colors.white,
      overlayColor: Colors.black,
      selectionColor: Colors.blue,
      titleStyle: const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      subtitleStyle: const TextStyle(
        color: Colors.black54,
        fontSize: 14,
      ),
      captionStyle: const TextStyle(
        color: Colors.black38,
        fontSize: 12,
      ),
      badgeStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Create a copy with modified values
  MediaTheme copyWith({
    Color? primaryColor,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? errorColor,
    Color? progressColor,
    Color? processingColor,
    Color? overlayColor,
    Color? selectionColor,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? captionStyle,
    TextStyle? badgeStyle,
    BorderRadius? tileBorderRadius,
    BorderRadius? buttonBorderRadius,
    BorderRadius? dialogBorderRadius,
    double? gridSpacing,
    double? tileAspectRatio,
    double? iconSize,
    double? selectionIndicatorSize,
    double? selectionBorderWidth,
    Duration? animationDuration,
    Curve? animationCurve,
    double? overlayOpacity,
    LinearGradient? overlayGradient,
    Widget Function(BuildContext context, double progress)? progressBuilder,
    Widget Function(BuildContext context)? emptyStateBuilder,
    Widget Function(BuildContext context, String error)? errorBuilder,
    Widget Function(BuildContext context)? loadingBuilder,
    Widget Function(BuildContext context)? processingOverlayBuilder,
  }) {
    return MediaTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      errorColor: errorColor ?? this.errorColor,
      progressColor: progressColor ?? this.progressColor,
      processingColor: processingColor ?? this.processingColor,
      overlayColor: overlayColor ?? this.overlayColor,
      selectionColor: selectionColor ?? this.selectionColor,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      captionStyle: captionStyle ?? this.captionStyle,
      badgeStyle: badgeStyle ?? this.badgeStyle,
      tileBorderRadius: tileBorderRadius ?? this.tileBorderRadius,
      buttonBorderRadius: buttonBorderRadius ?? this.buttonBorderRadius,
      dialogBorderRadius: dialogBorderRadius ?? this.dialogBorderRadius,
      gridSpacing: gridSpacing ?? this.gridSpacing,
      tileAspectRatio: tileAspectRatio ?? this.tileAspectRatio,
      iconSize: iconSize ?? this.iconSize,
      selectionIndicatorSize: selectionIndicatorSize ?? this.selectionIndicatorSize,
      selectionBorderWidth: selectionBorderWidth ?? this.selectionBorderWidth,
      animationDuration: animationDuration ?? this.animationDuration,
      animationCurve: animationCurve ?? this.animationCurve,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      overlayGradient: overlayGradient ?? this.overlayGradient,
      progressBuilder: progressBuilder ?? this.progressBuilder,
      emptyStateBuilder: emptyStateBuilder ?? this.emptyStateBuilder,
      errorBuilder: errorBuilder ?? this.errorBuilder,
      loadingBuilder: loadingBuilder ?? this.loadingBuilder,
      processingOverlayBuilder: processingOverlayBuilder ?? this.processingOverlayBuilder,
    );
  }

  /// Get overlay gradient for fullscreen viewers
  LinearGradient getOverlayGradient({bool fromTop = true}) {
    if (overlayGradient != null) return overlayGradient!;

    final colors = [
      overlayColor.withValues(alpha: overlayOpacity),
      Colors.transparent,
    ];

    return LinearGradient(
      begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
      end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
      colors: colors,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaTheme &&
        other.primaryColor == primaryColor &&
        other.backgroundColor == backgroundColor &&
        other.gridSpacing == gridSpacing;
  }

  @override
  int get hashCode => Object.hash(primaryColor, backgroundColor, gridSpacing);
}

/// InheritedWidget for accessing MediaTheme in the widget tree
class MediaThemeProvider extends InheritedWidget {
  final MediaTheme theme;

  const MediaThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  static MediaTheme of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<MediaThemeProvider>();
    return provider?.theme ?? const MediaTheme();
  }

  static MediaTheme? maybeOf(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<MediaThemeProvider>();
    return provider?.theme;
  }

  @override
  bool updateShouldNotify(MediaThemeProvider oldWidget) {
    return theme != oldWidget.theme;
  }
}
