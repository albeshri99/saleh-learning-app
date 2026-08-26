import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/app_typography.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/lesson.dart';
import '../../domain/models/timeline_event.dart';
import 'scenes/explanation_scene.dart';
import 'scenes/mcq_scene.dart';
import 'scenes/nasheed_scene.dart';
import 'scenes/pronunciation_scene.dart';
import 'scenes/review_scene.dart';
import 'scenes/success_scene.dart';
import 'scenes/welcome_scene.dart';
import 'scenes/writing_scene.dart';

/// قناة اتصال بين مشغّل سكربت صالح (في هيكل الدرس) والمشهد المعروض:
/// تبث أحداث الخط الزمني، وتعلن انتهاء كلام صالح.
class SceneChannel {
  final _events = StreamController<TimelineEvent>.broadcast();
  final ValueNotifier<bool> scriptFinished = ValueNotifier(false);

  Stream<TimelineEvent> get events => _events.stream;

  void emit(TimelineEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void markFinished() => scriptFinished.value = true;

  void dispose() {
    _events.close();
    scriptFinished.dispose();
  }
}

/// كل ما يحتاجه أي مشهد من المحرك — لا وصول مباشر لأي طبقة أدنى.
class SceneApi {
  const SceneApi({
    required this.profile,
    required this.channel,
    required this.completeScene,
    required this.recordAttempt,
    required this.recordAnswer,
    required this.triggerSaleh,
    required this.replayScene,
    required this.replayGeneration,
  });

  final ChildProfile profile;
  final SceneChannel channel;
  final VoidCallback completeScene;
  final VoidCallback recordAttempt;
  final void Function({required bool correct}) recordAnswer;

  /// A named one-shot reaction requested by an interactive lesson scene.
  final void Function(String action) triggerSaleh;

  /// يعيد تعليق المشهد وأحداثه المتزامنة من البداية.
  final VoidCallback replayScene;
  final int replayGeneration;
}

typedef SceneWidgetBuilder = Widget Function(Scene scene, SceneApi api);

/// سجل أنواع المشاهد. دعم نوع جديد = سطر واحد هنا + Widget جديد،
/// دون أي تعديل على المتحكم أو شاشة الدرس.
abstract class SceneRegistry {
  static final Map<SceneType, SceneWidgetBuilder> _builders = {
    SceneType.review: (s, a) => ReviewScene(scene: s, api: a),
    SceneType.welcome: (s, a) => WelcomeScene(scene: s, api: a),
    SceneType.nasheed: (s, a) => NasheedScene(scene: s, api: a),
    SceneType.explanation: (s, a) => ExplanationScene(scene: s, api: a),
    SceneType.pronunciation: (s, a) => PronunciationScene(scene: s, api: a),
    SceneType.guidedWriting: (s, a) => WritingScene(scene: s, api: a),
    SceneType.freeWriting: (s, a) => WritingScene(scene: s, api: a),
    SceneType.multipleChoice: (s, a) => McqScene(scene: s, api: a),
    SceneType.assessment: (s, a) => McqScene(scene: s, api: a),
    SceneType.success: (s, a) => SuccessScene(scene: s, api: a),
  };

  static Widget build(Scene scene, SceneApi api) {
    final builder = _builders[scene.type];
    if (builder != null) {
      // يضمن إنشاء State جديد عند الانتقال بين مشهدين من النوع نفسه
      // (الكتابة بالدليل ← الكتابة الحرة)، فلا يرث الثاني لوحة الأول.
      return KeyedSubtree(
        key: ValueKey(scene.id),
        child: builder(scene, api),
      );
    }
    // محتوى أحدث من نسخة التطبيق: لا ننهار، نعرض بديلًا ونسمح بالمتابعة.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('هذا النشاط غير مدعوم في نسخة التطبيق الحالية',
              style: AppTypography.subtitle),
          TextButton(
            onPressed: api.completeScene,
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }
}
