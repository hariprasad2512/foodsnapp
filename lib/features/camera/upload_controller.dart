import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/image/meal_image.dart';
import '../../core/utils/time.dart';
import '../../data/repositories/meal_asset_repository.dart';
import '../../data/repositories/meal_repository.dart';

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MealRepository(FirebaseFirestore.instance),
);

final mealAssetRepositoryProvider = Provider<MealAssetRepository>(
  (ref) => MealAssetRepository(FirebaseFirestore.instance),
);

/// Upload chip state machine (UI spec S06): `sending → sent | failed`.
/// The raw bytes are kept in memory for retry; the Firestore batch itself
/// is also queued by offline persistence while offline (TECH_SPEC §11).
enum UploadStatus { idle, sending, sent, failed }

class PendingMeal {
  final String relId;
  final String clientId;
  final Uint8List rawBytes;
  final String mealTag;
  final String? note;
  final DateTime capturedAt;

  const PendingMeal({
    required this.relId,
    required this.clientId,
    required this.rawBytes,
    required this.mealTag,
    this.note,
    required this.capturedAt,
  });
}

class UploadState {
  final UploadStatus status;
  final PendingMeal? pending; // kept for retry after failure

  const UploadState({this.status = UploadStatus.idle, this.pending});
}

class UploadController extends Notifier<UploadState> {
  int _attemptToken = 0;

  @override
  UploadState build() => const UploadState();

  /// Starts an upload. Returns immediately — S06 pops back to S05 while
  /// the work continues; progress surfaces through the UploadChip.
  Future<void> send({
    required String relId,
    required String clientId,
    required Uint8List rawBytes,
    required String mealTag,
    String? note,
    DateTime? capturedAt,
  }) async {
    final pending = PendingMeal(
      relId: relId,
      clientId: clientId,
      rawBytes: rawBytes,
      mealTag: mealTag,
      note: note,
      capturedAt: capturedAt ?? DateTime.now(),
    );
    state = UploadState(status: UploadStatus.sending, pending: pending);
    await _attempt(pending);
  }

  Future<void> retry() async {
    final pending = state.pending;
    if (pending == null || state.status != UploadStatus.failed) return;
    state = UploadState(status: UploadStatus.sending, pending: pending);
    await _attempt(pending);
  }

  void dismiss() {
    _attemptToken++;
    state = const UploadState();
  }

  Future<void> _attempt(PendingMeal pending) async {
    final token = ++_attemptToken;
    try {
      final processed = await processMealImage(pending.rawBytes);
      final meals = ref.read(mealRepositoryProvider);
      final mealId = meals.newMealId(pending.relId);
      final note = pending.note?.trim();
      // One atomic batch: meal metadata + both asset blobs. Firestore
      // persistence also queues this while offline (TECH_SPEC §11), so
      // `failed` here means validation/quota errors, not network loss.
      await meals.createMealWithAssets(
        relId: pending.relId,
        mealId: mealId,
        clientId: pending.clientId,
        mealTag: pending.mealTag,
        note: note == null || note.isEmpty ? null : note,
        photo: Blob(processed.photo),
        thumb: Blob(processed.thumb),
        localDate: localDateString(pending.capturedAt),
        localTime: localTimeString(pending.capturedAt),
      );
      if (token != _attemptToken) return;
      state = const UploadState(status: UploadStatus.sent);
      // "Sent ✓" shows for 1.5 s, then the chip disappears (UI spec S06).
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (token == _attemptToken && state.status == UploadStatus.sent) {
        state = const UploadState();
      }
    } catch (_) {
      if (token != _attemptToken) return;
      state = UploadState(status: UploadStatus.failed, pending: pending);
    }
  }
}

final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(UploadController.new);
