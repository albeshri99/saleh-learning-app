import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/lesson.dart';

void main() {
  test('محتوى درس الثاء يُفكك إلى نموذج الدرس بكل مشاهده', () {
    final raw = File('assets/content/lesson_tha.json').readAsStringSync();
    final lesson = Lesson.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(lesson.id, 'tha');
    expect(lesson.scenes, isNotEmpty);
    expect(lesson.scenes.first.type, SceneType.welcome);
    expect(lesson.scenes[1].type, SceneType.review);
    expect(lesson.scenes.last.type, SceneType.success);
    // التقويم الختامي غير قابل للتخطي كما حدد المحتوى.
    final assessment = lesson.scenes.singleWhere((s) => s.id == 'assessment_1');
    expect(assessment.canSkip, isFalse);
  });

  test('مخاطبة صالح تُحل حسب اسم الطفل وجنسه', () {
    final raw = File('assets/content/lesson_tha.json').readAsStringSync();
    final lesson = Lesson.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final welcome = lesson.scenes.singleWhere((s) => s.id == 'explain_1');
    final line = welcome.lines.first;

    expect(
      line.resolve(const ChildProfile(name: 'محمد', gender: ChildGender.male)),
      contains('انظرْ يا محمد'),
    );
    expect(
      line.resolve(
          const ChildProfile(name: 'فاطمة', gender: ChildGender.female)),
      contains('انظري يا فاطمة'),
    );
  });

  test('نوع مشهد غير معروف لا يكسر التفكيك', () {
    final scene = Scene.fromJson(const {
      'id': 'x',
      'type': 'somethingNew',
    });
    expect(scene.type, SceneType.unknown);
  });

  test('دليل الثاء والشرح يستخدمان الشكل نفسه ونقاطًا واضحة فوق الجسم', () {
    final raw = File('assets/content/lesson_tha.json').readAsStringSync();
    final lesson = Lesson.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final explanation = lesson.scenes.singleWhere((s) => s.id == 'explain_1');
    final guided = lesson.scenes.singleWhere((s) => s.id == 'write_guided_1');
    final explanationStrokes = explanation.data['strokes'] as List<dynamic>;
    final guidedStrokes = guided.data['strokes'] as List<dynamic>;

    expect(guidedStrokes, explanationStrokes);
    expect(guidedStrokes.length, 4);
    final dots = guidedStrokes.skip(1).cast<Map<String, dynamic>>();
    expect(dots.every((dot) => dot['kind'] == 'dot'), isTrue);
    expect(
      dots.every((dot) => (dot['center'] as List<dynamic>)[1] < .18),
      isTrue,
    );
  });
}

