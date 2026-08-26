import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/core/design/widgets/app_button.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/mcq_scene.dart';
import 'package:saleh_app/features/lesson/writing/letter_strokes.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';
import 'package:saleh_app/services/audio/audio_service.dart';

Lesson _loadAlif() {
  final raw = File('assets/content/lesson_alif.json').readAsStringSync();
  return Lesson.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  test('مسار الألف كثيف ويبدأ بالهمزة ثم جسم الألف', () {
    final lesson = _loadAlif();
    final guided =
        lesson.scenes.singleWhere((scene) => scene.id == 'write_guided_1');
    final strokes = StrokeSpec.listFromJson(guided.data['strokes'] as List);

    expect(strokes, hasLength(3));
    final hamzaUpper = strokes.first.samples(const Size(600, 300), count: 96);
    final hamzaLower = strokes[1].samples(const Size(600, 300), count: 96);
    final body = strokes.last.samples(const Size(600, 300), count: 96);
    expect(hamzaUpper, hasLength(97));
    expect(hamzaLower, hasLength(97));
    expect(body, hasLength(97));
    expect(hamzaUpper.first.dy, lessThan(body.first.dy));
    expect(hamzaLower.first.dy, lessThan(body.first.dy));
    expect(body.last.dy - body.first.dy, greaterThan(150));
  });

  test('مشتت حرف الثاء في تقويم الألف هو ثعلب لا ثوم', () {
    final lesson = _loadAlif();
    final assessment =
        lesson.scenes.singleWhere((scene) => scene.id == 'assessment_1');
    final questions =
        (assessment.data['questions'] as List).cast<Map<String, dynamic>>();
    final words = (questions.last['options'] as List).cast<String>();

    expect(words, contains('ثعلب'));
    expect(words, isNot(contains('ثوم')));
  });

  test('خيارات تقويم الكلمات تستخدم صورًا كرتونية مكتملة', () {
    final lesson = _loadAlif();
    final assessment =
        lesson.scenes.singleWhere((scene) => scene.id == 'assessment_1');
    final questions =
        (assessment.data['questions'] as List).cast<Map<String, dynamic>>();
    final images = (questions.last['optionImages'] as List).cast<String>();

    expect(images, hasLength(3));
    expect(images, contains('assets/images/assessment/alif_lion.png'));
    expect(images, contains('assets/images/assessment/duck.png'));
    expect(images, contains('assets/images/assessment/fox.png'));
    for (final image in images) {
      expect(File(image).existsSync(), isTrue, reason: image);
      expect(File(image).lengthSync(), greaterThan(0), reason: image);
    }
  });

  testWidgets('التتبع لا يقفز إلى النهاية ويكتمل بالترتيب', (tester) async {
    const stroke = StrokeSpec.path(
      [Offset(.5, .08), Offset(.5, .92)],
      aspectRatio: 1,
      widthFactor: 1,
      heightFactor: 1,
    );
    var completed = false;
    const canvasKey = ValueKey('guided-canvas');
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 240,
            child: GuidedTracingCanvas(
              key: canvasKey,
              letter: 'أَ',
              strokes: const [stroke],
              onStrokeCompleted: (_) {},
              onAllCompleted: () => completed = true,
            ),
          ),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byKey(canvasKey));
    final size = tester.getSize(find.byKey(canvasKey));
    final samples = stroke.samples(size, count: 96);

    final wrongStart = await tester.startGesture(origin + samples.last);
    await wrongStart.moveBy(const Offset(1, 1));
    await wrongStart.up();
    expect(completed, isFalse);

    final trace = await tester.startGesture(origin + samples.first);
    for (var i = 4; i < samples.length; i += 4) {
      await trace.moveTo(origin + samples[i]);
    }
    await trace.moveTo(origin + samples.last);
    await trace.up();
    expect(completed, isTrue);
  });

  testWidgets('زر الدرس ينفذ من أول ضغطة حتى عند حافته السفلية',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LessonActionButton(
              label: 'التالي',
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );

    final button = find.byType(LessonActionButton);
    final point = tester.getBottomRight(button) - const Offset(8, 8);
    final gesture = await tester.startGesture(point);
    await tester.pump();
    expect(taps, 1);
    await gesture.up();
  });

  testWidgets('التقويم يخفي نص السؤال الأول ولا ينتظر صوت النجاح',
      (tester) async {
    final lesson = _loadAlif();
    final assessment =
        lesson.scenes.singleWhere((scene) => scene.id == 'assessment_1');
    final audio = _NeverCompletingAudioService();
    var completed = 0;
    final channel = SceneChannel();
    addTearDown(() {
      channel.dispose();
      audio.dispose();
    });

    final api = SceneApi(
      profile: const ChildProfile(name: 'محمد', gender: ChildGender.male),
      channel: channel,
      completeScene: () => completed++,
      recordAttempt: () {},
      recordAnswer: ({required bool correct}) {},
      triggerSaleh: (_) {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioServiceProvider.overrideWithValue(audio)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 360,
              child: McqScene(scene: assessment, api: api),
            ),
          ),
        ),
      ),
    );

    expect(find.text('اضغط على حرف أَ'), findsNothing);
    await tester.tap(find.text('أَ'));
    await tester.pump();
    expect(find.text('السؤال التالي'), findsOneWidget);
    await tester.tap(find.text('السؤال التالي'));
    await tester.pump();
    await tester.tap(find.text('أَسد'));
    await tester.pump();
    expect(find.text('إنهاء التقويم'), findsOneWidget);
    await tester.tap(find.text('إنهاء التقويم'));
    await tester.pump();
    expect(completed, 1);
  });
}

class _NeverCompletingAudioService implements AudioService {
  final ValueNotifier<bool> _playing = ValueNotifier(false);
  final Completer<void> _never = Completer<void>();

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  Future<void> play(String assetPath) => _never.future;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async => _playing.dispose();
}
