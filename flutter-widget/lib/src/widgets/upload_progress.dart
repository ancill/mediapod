import 'package:flutter/material.dart';

import '../controllers/upload_controller.dart';
import '../models/upload_task.dart';

/// Widget showing upload progress for a single task
class UploadProgressItem extends StatelessWidget {
  final UploadTask task;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const UploadProgressItem({
    super.key,
    required this.task,
    this.onCancel,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.file.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _buildProgressIndicator(),
                  const SizedBox(height: 2),
                  _buildStatusText(context),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (task.status) {
      case UploadStatus.queued:
        icon = Icons.hourglass_empty;
        color = Colors.grey;
        break;
      case UploadStatus.uploading:
        icon = Icons.cloud_upload;
        color = Colors.blue;
        break;
      case UploadStatus.processing:
        icon = Icons.hourglass_top;
        color = Colors.orange;
        break;
      case UploadStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case UploadStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
      case UploadStatus.cancelled:
        icon = Icons.cancel;
        color = Colors.grey;
        break;
    }

    return Icon(icon, color: color, size: 32);
  }

  Widget _buildProgressIndicator() {
    if (task.status == UploadStatus.completed ||
        task.status == UploadStatus.cancelled) {
      return const SizedBox.shrink();
    }

    if (task.status == UploadStatus.processing) {
      return const LinearProgressIndicator();
    }

    return LinearProgressIndicator(
      value: task.status == UploadStatus.queued ? 0 : task.progress,
    );
  }

  Widget _buildStatusText(BuildContext context) {
    String text;
    Color? color;

    switch (task.status) {
      case UploadStatus.queued:
        text = 'Waiting...';
        color = Colors.grey;
        break;
      case UploadStatus.uploading:
        text = 'Uploading ${task.progressPercent}';
        color = Colors.blue;
        break;
      case UploadStatus.processing:
        text = 'Processing...';
        color = Colors.orange;
        break;
      case UploadStatus.completed:
        text = 'Completed';
        color = Colors.green;
        break;
      case UploadStatus.failed:
        text = 'Failed: ${task.error}';
        color = Colors.red;
        break;
      case UploadStatus.cancelled:
        text = 'Cancelled';
        color = Colors.grey;
        break;
    }

    return Text(
      text,
      style: TextStyle(fontSize: 12, color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionButton() {
    if (task.canCancel) {
      return IconButton(
        icon: const Icon(Icons.close),
        onPressed: onCancel,
        tooltip: 'Cancel',
      );
    }

    if (task.canRetry) {
      return IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: onRetry,
        tooltip: 'Retry',
      );
    }

    if (task.isFinished && onDismiss != null) {
      return IconButton(
        icon: const Icon(Icons.close),
        onPressed: onDismiss,
        tooltip: 'Dismiss',
      );
    }

    return const SizedBox.shrink();
  }
}

/// Widget showing a list of upload tasks
class UploadProgressList extends StatelessWidget {
  final UploadController controller;
  final bool showCompleted;
  final bool showFailed;

  const UploadProgressList({
    super.key,
    required this.controller,
    this.showCompleted = true,
    this.showFailed = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tasks = controller.allTasks.where((task) {
          if (!showCompleted && task.status == UploadStatus.completed) {
            return false;
          }
          if (!showFailed && task.status == UploadStatus.failed) {
            return false;
          }
          return true;
        }).toList();

        if (tasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return UploadProgressItem(
              task: task,
              onCancel: task.canCancel ? () => controller.cancel(task.id) : null,
              onRetry: task.canRetry ? () => controller.retry(task.id) : null,
              onDismiss: task.isFinished ? () => controller.remove(task.id) : null,
            );
          },
        );
      },
    );
  }
}

/// Compact upload progress bar for showing in app bar or bottom bar
class UploadProgressBar extends StatelessWidget {
  final UploadController controller;
  final VoidCallback? onTap;

  const UploadProgressBar({
    super.key,
    required this.controller,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.hasActiveUploads) {
          return const SizedBox.shrink();
        }

        final pending = controller.pendingTasks;
        final uploading = pending
            .where((t) => t.status == UploadStatus.uploading)
            .toList();

        // Calculate overall progress
        double totalProgress = 0;
        for (final task in uploading) {
          totalProgress += task.progress;
        }
        final avgProgress =
            uploading.isEmpty ? 0.0 : totalProgress / uploading.length;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Uploading ${pending.length} file${pending.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      LinearProgressIndicator(
                        value: avgProgress,
                        minHeight: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
