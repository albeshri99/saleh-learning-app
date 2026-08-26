import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/mcq_scene.dart';
import 'package:saleh_app/services/audio/audio_service.dart';

Lesson _loadAlif() {
  final raw = File('assets/content/lesson_alif.json').readAsStringSync();
  return Lesson.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  testWidgets('صور حيوانات التقويم كاملة داخل إطار موحد على iPad الأفقي',
      (tester) async {
    final lesson = _loadAlif();
    final assessment =
        lesson.scenes.singleWhere((scene) => scene.id == 'assessment_1');
    final audio = _SilentAudioService();
    final channel = SceneChannel();
    addTearDown(() {
      channel.dispose();
      audio.dispose();
    });

    final api = SceneApi(
      profile: const ChildProfile(name: 'محمد', gender: ChildGender.male),
      channel: channel,
      completeScene: () {},
      recordAttempt: () {},
      recordAnswer: ({required bool correct}) {},
      triggerSaleh: (_) {},
      replayScene: () {},
      replayGeneration: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioServiceProvider.overrideWithValue(audio)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1024,
              height: 360,
              child: McqScene(scene: assessment, api: api),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('أَ'));
    await tester.pump();
    await tester.tap(find.text('السؤال التالي'));
    await tester.pump();

    const assets = [
      'assets/images/assessment/alif_lion.png',
      'assets/images/assessment/duck.png',
      'assets/images/assessment/fox.png',
    ];
    for (final asset in assets) {
      final finder = find.byKey(
        ValueKey('assessment-option-image-$asset'),
      );
      expect(finder, findsOneWidget);
      final image = tester.widget<Image>(finder);
      expect(image.fit, BoxFit.contain);
      expect(image.alignment, Alignment.center);

      expect(tester.getSize(finder).isEmpty, isFalse);
    }

    // لا يوجد قص إضافي حول الصور؛ يبقى الحيوان كاملًا داخل البطاقة.
    expect(
      find.descendant(
        of: find.byType(McqScene),
        matching: find.byType(ClipRect),
      ),
      findsNothing,
    );
  });
}

class _SilentAudioService implements AudioService {
  final ValueNotifier<bool> _playing = ValueNotifier(false);

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  Future<void> play(String assetPath) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async => _playing.dispose();
}
