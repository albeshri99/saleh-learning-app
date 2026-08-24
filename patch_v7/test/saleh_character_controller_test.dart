import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/lesson/character/saleh_character_controller.dart';
import 'package:saleh_app/features/lesson/widgets/saleh_character.dart';

void main() {
  group('SalehCharacterController', () {
    late ValueNotifier<bool> audio;
    late SalehCharacterController controller;

    setUp(() {
      audio = ValueNotifier(false);
      controller = SalehCharacterController(audioPlaying: audio);
    });

    tearDown(() {
      controller.dispose();
      audio.dispose();
    });

    test('بلا صوت يبقى صالح idle', () {
      expect(controller.pose, SalehPose.idle);
    });

    test('بداية الصوت ← talking، ونهايته ← عودة إلى idle', () {
      audio.value = true;
      expect(controller.pose, SalehPose.talking);
      audio.value = false;
      expect(controller.pose, SalehPose.idle);
    });

    test('الحالات الأدائية من المحرك لها الأولوية على talking', () {
      controller.setPose(SalehPose.pointing);
      audio.value = true;
      expect(controller.pose, SalehPose.pointing);
      controller.reset();
      expect(controller.pose, SalehPose.talking); // الصوت ما زال يعمل
    });

    test('التشجيع يبقى حتى انتقال المشهد ولا ينتهي بانتهاء دورة الفيديو', () {
      controller.setPose(SalehPose.encouraging);
      expect(controller.pose, SalehPose.encouraging);
      controller.notifyPoseCompleted(SalehPose.encouraging);
      expect(controller.pose, SalehPose.encouraging);
      controller.reset();
      expect(controller.pose, SalehPose.idle);
    });

    test('talking لا تُقبل كطلب دلالي — الصوت وحده يقودها', () {
      controller.setPose(SalehPose.talking);
      expect(controller.pose, SalehPose.idle);
    });

    test('تغير الصوت يبلغ المستمعين', () {
      var notified = 0;
      controller.addListener(() => notified++);
      audio.value = true;
      expect(notified, 1);
    });
  });
}

