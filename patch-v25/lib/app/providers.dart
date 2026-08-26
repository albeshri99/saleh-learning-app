import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/local_progress_repository.dart';
import '../data/mock/mock_content_repository.dart';
import '../domain/models/child_profile.dart';
import '../domain/models/curriculum.dart';
import '../domain/repositories/content_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../services/audio/audio_service.dart';
import '../services/speech/speech_service.dart';

/// نقطة التوصيل الوحيدة بين الواجهة والتنفيذات.
/// استبدال Mock بـ Firebase مستقبلًا = تغيير هذه الأسطر فقط.
final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => MockContentRepository());

final progressRepositoryProvider =
    Provider<ProgressRepository>((ref) => LocalProgressRepository());

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AssetAudioService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = DeviceSpeechService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final programsProvider = FutureProvider<List<Program>>(
  (ref) => ref.watch(contentRepositoryProvider).loadPrograms(),
);

/// ملف الطفل الحالي — يُحمَّل من التخزين وتُحفظ تعديلاته فيه.
class ChildProfileNotifier extends AsyncNotifier<ChildProfile> {
  @override
  Future<ChildProfile> build() async {
    final saved = await ref.read(progressRepositoryProvider).loadProfile();
    return saved ?? const ChildProfile(name: 'محمد', gender: ChildGender.male);
  }

  Future<void> setProfile(ChildProfile profile) async {
    state = AsyncData(profile);
    await ref.read(progressRepositoryProvider).saveProfile(profile);
  }
}

final childProfileProvider =
    AsyncNotifierProvider<ChildProfileNotifier, ChildProfile>(
  ChildProfileNotifier.new,
);
