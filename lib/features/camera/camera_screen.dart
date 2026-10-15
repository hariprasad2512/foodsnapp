import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/capture_service.dart';
import '../pairing/relationship_providers.dart';
import 'preview_screen.dart';
import 'upload_chip.dart';
import 'upload_controller.dart';

/// S05 — Camera (client, center page). Always dark (UI spec §5).
///
/// Android: full-bleed live preview. Web: no viewfinder — a large
/// Take photo button opens the device camera via the browser (UI spec S05).
/// Shutter/gallery both land on S06 (PreviewScreen) with the raw bytes.
class CameraScreen extends ConsumerStatefulWidget {
  /// 0 = timeline, 2 = history (S04 edge navigation).
  final ValueChanged<int> onPage;

  const CameraScreen({super.key, required this.onPage});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

enum _CamState { initializing, ready, permissionDenied, error }

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  _CamState _state = _CamState.initializing;
  FlashMode _flash = FlashMode.off;
  bool _flashing = false; // 120 ms white shutter flash
  Offset? _focusPoint; // tap-to-focus indicator
  double _zoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  final _capture = CaptureService();

  bool get _isWeb => kIsWeb;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_isWeb) _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(describing: controller.description);
    }
  }

  Future<void> _initCamera({CameraDescription? describing}) async {
    setState(() => _state = _CamState.initializing);
    await _controller?.dispose();
    _controller = null;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _state = _CamState.error);
        return;
      }
      final selected = describing ??
          _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(_flash);
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _zoom = 1.0;
      _controller = controller;
      if (mounted) setState(() => _state = _CamState.ready);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _state = _isPermissionError(e)
            ? _CamState.permissionDenied
            : _CamState.error);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _CamState.error);
    }
  }

  static bool _isPermissionError(CameraException e) {
    final code = e.code.toLowerCase();
    final desc = (e.description ?? '').toLowerCase();
    return code.contains('denied') ||
        code.contains('permission') ||
        desc.contains('denied') ||
        desc.contains('permission');
    // TODO(spec): permanently-denied case should offer "Open settings"
    // (UI spec S05) — needs an app-settings deep link plugin.
  }

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    final current = _controller?.description;
    final next = _cameras.firstWhere(
      (c) => c != current,
      orElse: () => _cameras.first,
    );
    await _initCamera(describing: next);
  }

  void _cycleFlash() {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    _controller?.setFlashMode(next);
    setState(() => _flash = next);
  }

  Future<void> _shutter() async {
    final controller = _controller;
    if (_state != _CamState.ready ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }
    await HapticFeedback.lightImpact();
    setState(() => _flashing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) _openPreview(bytes);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't start the camera")),
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted) setState(() => _flashing = false);
    }
  }

  Future<void> _gallery() async {
    final bytes = await _capture.pickFromGallery();
    if (bytes != null && mounted) _openPreview(bytes);
  }

  Future<void> _webTakePhoto() async {
    final bytes = await _capture.takePhoto();
    if (bytes != null && mounted) _openPreview(bytes);
  }

  void _openPreview(Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(imageBytes: bytes),
      ),
    );
  }

  void _onTapFocus(TapDownDetails details, Size previewSize) {
    final controller = _controller;
    if (controller == null) return;
    final point = Offset(
      details.localPosition.dx / previewSize.width,
      details.localPosition.dy / previewSize.height,
    );
    controller.setFocusPoint(point).catchError((Object _) {});
    setState(() => _focusPoint = details.localPosition);
    Future<void>.delayed(const Duration(milliseconds: 600)).then((_) {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  void _onZoomScaleUpdate(ScaleUpdateDetails details) {
    final controller = _controller;
    if (controller == null) return;
    final next = (_zoom * details.scale).clamp(_minZoom, _maxZoom);
    controller.setZoomLevel(next).catchError((Object _) {});
    setState(() => _zoom = next);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UploadState>(uploadControllerProvider, (prev, next) {
      if (prev?.status != UploadStatus.sent &&
          next.status == UploadStatus.sent) {
        HapticFeedback.mediumImpact();
      }
    });
    final rel = ref.watch(activeRelationshipProvider).value;
    final streak = rel?.streakCount ?? 0;
    final unread = rel?.unreadForClient ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBody()),
            // Reserved slot for the future daily calorie ring (UI spec §9).
            // Layout space is kept; nothing renders in v1.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(height: 8),
            ),
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: _TopBar(
                flash: _flash,
                streak: streak,
                canFlip: _cameras.length > 1,
                onFlash: _cycleFlash,
                onFlip: _flip,
                onSettings: () => context.push('/settings'),
              ),
            ),
            const Positioned(
              top: 64,
              left: 0,
              right: 0,
              child: Center(child: UploadChip()),
            ),
            if (_state == _CamState.ready && !_isWeb)
              _EdgeHints(
                hasUnread: unread > 0,
                onChat: () => widget.onPage(0),
                onHistory: () => widget.onPage(2),
              ),
            if (_state == _CamState.ready && !_isWeb)
              _BottomBar(
                onShutter: _shutter,
                onGallery: _gallery,
              ),
            if (_flashing)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isWeb) return _WebVariant(onTakePhoto: _webTakePhoto);
    return switch (_state) {
      _CamState.initializing =>
        const Center(child: CircularProgressIndicator(color: Colors.white)),
      _CamState.permissionDenied => _PermissionState(onAllow: _initCamera),
      _CamState.error => _ErrorState(
          onRetry: _initCamera,
          onGallery: _gallery,
        ),
      _CamState.ready => Builder(
          builder: (context) {
            final controller = _controller;
            if (controller == null || !controller.value.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return GestureDetector(
                  onTapDown: (d) => _onTapFocus(d, size),
                  onScaleUpdate: _onZoomScaleUpdate,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(controller),
                      if (_focusPoint != null)
                        Positioned(
                          left: _focusPoint!.dx - 30,
                          top: _focusPoint!.dy - 30,
                          child: const IgnorePointer(
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.fromBorderSide(
                                    BorderSide(
                                        color: Colors.white, width: 1.5),
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
    };
  }
}

class _TopBar extends StatelessWidget {
  final FlashMode flash;
  final int streak;
  final bool canFlip;
  final VoidCallback onFlash;
  final VoidCallback onFlip;
  final VoidCallback onSettings;

  const _TopBar({
    required this.flash,
    required this.streak,
    required this.canFlip,
    required this.onFlash,
    required this.onFlip,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Flash ${flash.name}',
            icon: Icon(
              switch (flash) {
                FlashMode.off => Icons.flash_off,
                FlashMode.auto => Icons.flash_auto,
                _ => Icons.flash_on,
              },
              color: Colors.white,
            ),
            onPressed: onFlash,
          ),
          Expanded(
            child: Center(
              child: streak > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '🔥 $streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          if (canFlip)
            IconButton(
              tooltip: 'Flip camera',
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: onFlip,
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

/// Subtle edge icons doubling as swipe hints (UI spec S05).
class _EdgeHints extends StatelessWidget {
  final bool hasUnread;
  final VoidCallback onChat;
  final VoidCallback onHistory;

  const _EdgeHints({
    required this.hasUnread,
    required this.onChat,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Center(
            child: IconButton(
              tooltip: 'Open chat',
              onPressed: onChat,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat_bubble_outline, color: Colors.white70),
                  if (hasUnread)
                    const Positioned(
                      right: -2,
                      top: -2,
                      child: SizedBox(
                        width: 10,
                        height: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF8E8EF5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Center(
            child: IconButton(
              tooltip: 'Open history',
              onPressed: onHistory,
              icon: const Icon(Icons.history, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onShutter;
  final VoidCallback onGallery;

  const _BottomBar({required this.onShutter, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Pick from gallery',
              // TODO(spec): show the last-photo thumbnail (44 dp, UI spec
              // S05) — needs a media-store reader plugin.
              icon: const Icon(
                Icons.photo_library_outlined,
                color: Colors.white,
                size: 32,
              ),
              onPressed: onGallery,
            ),
          ),
          Semantics(
            button: true,
            label: 'Take photo',
            child: GestureDetector(
              onTap: onShutter,
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}

/// Web S05 variant: same dark layout, no live viewfinder (UI spec S05).
class _WebVariant extends StatelessWidget {
  final VoidCallback onTakePhoto;

  const _WebVariant({required this.onTakePhoto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt, color: Colors.white54, size: 64),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onTakePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take photo'),
          ),
        ],
      ),
    );
  }
}

class _PermissionState extends StatelessWidget {
  final VoidCallback onAllow;

  const _PermissionState({required this.onAllow});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              'FoodSnap needs your camera to snap your meals',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAllow,
              child: const Text('Allow camera'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onGallery;

  const _ErrorState({required this.onRetry, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Couldn't start the camera",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onGallery,
              child: const Text('Pick from gallery instead'),
            ),
          ],
        ),
      ),
    );
  }
}
