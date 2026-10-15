import 'package:flutter/material.dart';

/// Shared banner (UI spec §7): S14 notification/install prompts and the
/// offline notice. Dismissible per session via [onDismiss.
///
/// Spark note (TECH_SPEC §17): the S14 notification/install banners stay
/// hidden until/unless Blaze lands — this widget currently serves the
/// offline notice (M6) and future banners. TODO(Blaze).
class AppBanner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const AppBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              if (onDismiss != null)
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
