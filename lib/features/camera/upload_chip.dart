import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'upload_controller.dart';

/// Upload progress chip fixed at the top of S05 (UI spec §7 + microcopy
/// §11). States: sending ("Sending…" + spinner), sent ("Sent ✓" for 1.5 s),
/// failed ("Couldn't send · Retry" in red — tapping retries). Hidden idle.
class UploadChip extends ConsumerWidget {
  const UploadChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(uploadControllerProvider);
    return switch (upload.status) {
      UploadStatus.idle => const SizedBox.shrink(),
      UploadStatus.sending => const _Chip(
          background: Colors.black54,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Text('Sending…'),
            ],
          ),
        ),
      UploadStatus.sent => const _Chip(
          background: Colors.black54,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 16, color: Colors.white),
              SizedBox(width: 4),
              Text('Sent ✓'),
            ],
          ),
        ),
      UploadStatus.failed => _Chip(
          background: Colors.black54,
          onTap: () => ref.read(uploadControllerProvider.notifier).retry(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 16, color: Color(0xFFFF6B70)),
              SizedBox(width: 4),
              Text("Couldn't send · Retry"),
            ],
          ),
        ),
    };
  }
}

class _Chip extends StatelessWidget {
  final Widget child;
  final Color background;
  final VoidCallback? onTap;

  const _Chip({required this.child, required this.background, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          child: child,
        ),
      ),
    );
  }
}
