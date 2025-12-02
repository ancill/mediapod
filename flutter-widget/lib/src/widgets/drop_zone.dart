import 'package:flutter/material.dart';

/// A widget that accepts drag-and-drop files (web/desktop)
class DropZone extends StatefulWidget {
  /// Child widget
  final Widget child;

  /// Called when files are dropped
  final void Function(List<String> paths)? onDrop;

  /// Whether drop zone is enabled
  final bool enabled;

  /// Overlay shown when dragging over
  final Widget? dragOverlay;

  const DropZone({
    super.key,
    required this.child,
    this.onDrop,
    this.enabled = true,
    this.dragOverlay,
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // Note: Full drag-drop implementation requires platform-specific code
    // For now, we show a visual indicator but actual drop handling
    // needs desktop_drop or similar package for full functionality

    return Stack(
      children: [
        widget.child,
        if (_isDragging && widget.enabled)
          Positioned.fill(child: widget.dragOverlay ?? _buildDefaultOverlay()),
      ],
    );
  }

  Widget _buildDefaultOverlay() {
    return Container(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_upload, size: 64, color: Colors.blue[400]),
              const SizedBox(height: 16),
              Text(
                'Drop files to upload',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A visual drop target that can be shown in empty states
class DropTarget extends StatelessWidget {
  /// Called when tapped (as alternative to drag-drop)
  final VoidCallback? onTap;

  /// Label text
  final String label;

  /// Sublabel text
  final String? sublabel;

  /// Icon to display
  final IconData icon;

  const DropTarget({
    super.key,
    this.onTap,
    this.label = 'Drop files here',
    this.sublabel,
    this.icon = Icons.cloud_upload_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey[300]!,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[50],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 8),
              Text(
                sublabel!,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            if (onTap != null)
              ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.folder_open),
                label: const Text('Browse Files'),
              ),
          ],
        ),
      ),
    );
  }
}
