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
import 'package:saleh_app/features/lesson/scenes/writing_scene.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/features/lesson/writing/letter_strokes.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'package:saleh_app/services/speech/speech_service.dart';

Lesson _loadAlif() {
  final raw = File('assets/content/lesson_alif.json').readAsStringSync();
  return Lesson.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  test('قالب الفيديو يكتب جسم الألف ثم الهمزة ثم الفتحة', () {
    final lesson = _loadAlif();
    final guided =
        lesson.scenes.singleWhere((scene) => scene.id == 'write_guided_1');
    final template =
        LetterTraceTemplate.fromId(guided.data['traceTemplateId'] as String);
    final strokes = template!.strokes;

    expect(strokes, hasLength(3));
    final body = strokes.first.samples(const Size(600, 300), count: 96);
    final hamza = strokes[1].samples(const Size(600, 300), count: 96);
    final fatha = strokes.last.samples(const Size(600, 300), count: 96);

    expect(body, hasLength(97));
    expect(body.last.dy - body.first.dy, greaterThan(150));
    expect(hamza, hasLength(97));
    expect(hamza.first.dy, lessThan(body.first.dy));
    expect(fatha, hasLength(97));
    expect(fatha.first.dy, lessThan(hamza.first.dy));
    expect(fatha.last.dx, lessThan(fatha.first.dx));

    // والمؤشر التفاعلي يأخذ عيناته من منحنى القالب نفسه بكثافة عالية، لا
    // من أضلاع تقريبية تختلف عن تعبئة اللون.
    final smoothHamza = template.samples(
      const Size(600, 300),
      1,
      count: 240,
    );
    expect(smoothHamza, hasLength(241));
    final steps = <double>[
      for (var i = 1; i < smoothHamza.length; i++)
        (smoothHamza[i] - smoothHamza[i - 1]).distance,
    ];
    expect(steps.reduce((a, b) => a > b ? a : b), lessThan(2));
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

  test('الشرح يستخدم صورة الأسد المعتمدة وكل حروف التقويم مشكلة بالفتحة', () {
    final lesson = _loadAlif();
    final explanation =
        lesson.scenes.singleWhere((scene) => scene.id == 'explain_1');
    final example = explanation.data['example'] as Map<String, dynamic>;
    expect(example['imageAsset'], 'assets/images/assessment/alif_lion.png');

    final assessment =
        lesson.scenes.singleWhere((scene) => scene.id == 'assessment_1');
    final questions =
        (assessment.data['questions'] as List).cast<Map<String, dynamic>>();
    final letters = (questions.first['options'] as List).cast<String>();
    expect(letters, everyElement(contains('\u064E')));
  });

  test('التحقق الصوتي يقبل صيغ تفريغ صوت آ الواقعية', () {
    expect(speechMatchesExpected('أَ', 'آ'), isTrue);
    expect(speechMatchesExpected('آ', 'آ'), isTrue);
    expect(speechMatchesExpected('آه', 'آ'), isTrue);
    expect(speechMatchesExpected('ألف', 'آ'), isTrue);
    expect(speechMatchesExpected('باء', 'آ'), isFalse);
    expect(speechMatchesExpected('', 'آ'), isFalse);
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

  testWidgets('التتبع يقبل سحبًا سريعًا بأحداث لمس متباعدة', (tester) async {
    const stroke = StrokeSpec.path(
      [Offset(.5, .08), Offset(.5, .92)],
      aspectRatio: 1,
      widthFactor: 1,
      heightFactor: 1,
    );
    var completed = false;
    const canvasKey = ValueKey('sparse-guided-canvas');
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
    final trace = await tester.startGesture(origin + samples.first);
    for (var i = 10; i < samples.length; i += 10) {
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

  testWidgets('الكتابة الحرة ترفض الخربشة وتقبل أَ من ضغطة واحدة',
      (tester) async {
    final lesson = _loadAlif();
    final freeWriting =
        lesson.scenes.singleWhere((scene) => scene.id == 'write_free_1');
    var completed = 0;
    final audio = _ControllableAudioService();
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
      replayScene: () {},
      replayGeneration: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioServiceProvider.overrideWithValue(audio)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 560,
              child: WritingScene(scene: freeWriting, api: api),
            ),
          ),
        ),
      ),
    );

    final canvas = find.byType(FreeWritingCanvas);
    final origin = tester.getTopLeft(canvas);
    final size = tester.getSize(canvas);

    Future<void> draw(List<Offset> normalized) async {
      final gesture = await tester.startGesture(
        origin +
            Offset(normalized.first.dx * size.width,
                normalized.first.dy * size.height),
      );
      for (final point in normalized.skip(1)) {
        await gesture.moveTo(
          origin + Offset(point.dx * size.width, point.dy * size.height),
        );
      }
      await gesture.up();
      await tester.pump();
    }

    await draw(const [Offset(.20, .40), Offset(.80, .45)]);
    await tester.tap(find.text('انتهيت'));
    await tester.pump();
    expect(completed, 0);
    expect(find.byKey(const ValueKey('free-writing-validation-message')),
        findsOneWidget);

    await tester.tap(find.text('مسح'));
    await tester.pump();
    await draw(const [
      Offset(.52, .30),
      Offset(.50, .39),
      Offset(.49, .51),
      Offset(.50, .64),
      Offset(.51, .76),
      Offset(.49, .87),
    ]);
    await draw(const [
      Offset(.56, .20),
      Offset(.51, .19),
      Offset(.45, .20),
      Offset(.41, .23),
      Offset(.42, .26),
      Offset(.48, .28),
      Offset(.55, .28),
      Offset(.53, .30),
      Offset(.47, .32),
      Offset(.41, .32),
    ]);
    await draw(const [
      Offset(.42, .13),
      Offset(.46, .12),
      Offset(.51, .105),
      Offset(.56, .09),
    ]);

    await tester.tap(find.text('انتهيت'));
    await tester.pump();
    expect(
      find.text('أحسنت، لقد كتبت حرف الألف بطريقة صحيحة ممتازة'),
      findsOneWidget,
    );
    expect(audio.lastAsset, 'assets/audio/alif/free_success.mp3');
    expect(completed, 0);
    audio.finish();
    await tester.pump();
    expect(completed, 1);
  });

  testWidgets('التقويم يخفي نص السؤال الأول ولا ينتظر صوت النجاح',
      (tester) async {
    final lesson = _loadAlif();
    final assessment =
        lesson.scenes.singleWhere((scene) => scene.id == 'assessment_1');
    final audio = _NeverCompletingAudioService();
    final salehActions = <String>[];
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
      triggerSaleh: salehActions.add,
      replayScene: () {},
      replayGeneration: 0,
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
    expect(salehActions.last, 'happyOnce');
    expect(find.text('السؤال التالي'), findsOneWidget);
    await tester.tap(find.text('السؤال التالي'));
    await tester.pump();
    expect(salehActions.last, 'idle');
    await tester.tap(find.text('أَسد'));
    await tester.pump();
    expect(salehActions.last, 'happyOnce');
    expect(find.text('إنهاء التقويم'), findsOneWidget);
    await tester.tap(find.text('إنهاء التقويم'));
    await tester.pump();
    expect(completed, 1);
  });
}

class _ControllableAudioService implements AudioService {
  final ValueNotifier<bool> _playing = ValueNotifier(false);
  Completer<void>? _completer;
  String? lastAsset;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  Future<void> play(String assetPath) {
    lastAsset = assetPath;
    _playing.value = true;
    _completer = Completer<void>();
    return _completer!.future.whenComplete(() => _playing.value = false);
  }

  void finish() {
    if (!(_completer?.isCompleted ?? true)) _completer!.complete();
  }

  @override
  Future<void> stop() async => finish();

  @override
  Future<void> dispose() async {
    finish();
    _playing.dispose();
  }
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
