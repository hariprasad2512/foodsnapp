import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/time.dart';
import '../pairing/relationship_providers.dart';
import 'meal_tag_chip.dart';
import 'upload_controller.dart';

/// S06 — Preview & Send (client). Dark screen: photo fills the viewport
/// (contain, black bars allowed); ✕ discards; bottom translucent panel with
/// tag chips (one preselected by time of day), optional note, Send button.
///
/// Send hands the bytes to [UploadController] and immediately pops back to
/// S05 — progress surfaces through the UploadChip there (UI spec S06).
class PreviewScreen extends ConsumerStatefulWidget {
  final Uint8List imageBytes;

  /// Overridable for tests (default-tag selection uses the device clock).
  final DateTime? now;

  const PreviewScreen({super.key, required this.imageBytes, this.now});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  late String _tag;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tag = tagForTime(widget.now ?? DateTime.now());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _send(String relId, String clientId) {
    ref.read(uploadControllerProvider.notifier).send(
          relId: relId,
          clientId: clientId,
          rawBytes: widget.imageBytes,
          mealTag: _tag,
          note: _note.text,
          capturedAt: DateTime.now(),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Jank notes (keyboard-open path must stay at ~1 frame budget):
    // - The Scaffold never resizes with the keyboard, so the 12MP preview
    //   keeps a fixed size (no resample per animation frame).
    // - This build method reads NO MediaQuery metrics, so keyboard animation
    //   frames do not rebuild this subtree. Only _KeyboardAvoider below
    //   rebuilds, and it reuses the same child instance, so the TextField
    //   builds once instead of once per animation frame.
    // - The preview sits behind a RepaintBoundary: panel animation
    //   re-composites the cached image layer instead of repainting it.
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: _PreviewImage(bytes: widget.imageBytes),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: 'Discard',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _KeyboardAvoider(
                child: _SendPanel(
                  tag: _tag,
                  note: _note,
                  onTag: (t) => setState(() => _tag = t),
                  onSend: _send,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen preview. The bytes are decoded once at screen width
/// (cacheWidth) and the RepaintBoundary above keeps panel animation to
/// compositing instead of repainting the photo.
class _PreviewImage extends StatelessWidget {
  final Uint8List bytes;

  const _PreviewImage({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      cacheWidth: 1080,
      gaplessPlayback: true,
    );
  }
}

/// Rides its [child] above the keyboard. This is the ONLY widget on S06
/// that reads the keyboard inset, so animation frames rebuild just this
/// padding — [child] is the same instance every tick and is not rebuilt.
class _KeyboardAvoider extends StatelessWidget {
  final Widget child;

  const _KeyboardAvoider({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: child,
    );
  }
}

/// Bottom translucent panel: tag chips, note field, Send button.
/// Watches the relationship itself so stream events rebuild only this small
/// panel, never the full-screen image above it.
class _SendPanel extends ConsumerWidget {
  final String tag;
  final TextEditingController note;
  final ValueChanged<String> onTag;
  final void Function(String relId, String clientId) onSend;

  const _SendPanel({
    required this.tag,
    required this.note,
    required this.onTag,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rel = ref.watch(activeRelationshipProvider).value;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: Colors.black54),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in mealTags)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MealTagChip(
                      tag: t,
                      selected: t == tag,
                      onTap: () => onTag(t),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: note,
                  maxLength: 200,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add a note (optional)',
                    hintStyle: TextStyle(color: Colors.white54),
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                height: 56,
                child: FilledButton(
                  onPressed:
                      rel == null ? null : () => onSend(rel.id, rel.clientId),
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: Semantics(
                    button: true,
                    label: 'Send',
                    child: const Icon(Icons.arrow_upward),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
