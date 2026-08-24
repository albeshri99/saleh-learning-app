import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';

void main() {
  test('لا يسمح زر التالي العام بتجاوز الكتابة الحرة', () {
    expect(lessonSceneAllowsGlobalNext(SceneType.freeWriting), isFalse);
    expect(lessonSceneAllowsGlobalNext(SceneType.guidedWriting), isFalse);
    expect(lessonSceneAllowsGlobalNext(SceneType.multipleChoice), isFalse);
    expect(lessonSceneAllowsGlobalNext(SceneType.welcome), isTrue);
  });

  testWidgets('لوحة الكتابة الحرة تسجل حبر الطفل', (tester) async {
    var hasInk = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 260,
            child: FreeWritingCanvas(
              onInkChanged: (value) => hasInk = value,
            ),
          ),
        ),
      ),
    );

    await tester.dragFrom(const Offset(80, 100), const Offset(260, 40));
    await tester.pump();
    expect(hasInk, isTrue);
  });
}

