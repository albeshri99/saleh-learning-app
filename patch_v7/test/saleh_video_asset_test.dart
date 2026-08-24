import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/character/video/saleh_video_clips.dart';
import 'package:saleh_app/features/lesson/widgets/saleh_character.dart';

void main() {
  test('كل حالات الفيديو تسجل أصول Alpha وPosters موجودة', () {
    for (final pose in SalehPose.values) {
      final clip = SalehVideoClips.forPose(pose);
      expect(clip.asset, endsWith('.webm'));
      expect(clip.poster, endsWith('.png'));
      expect(File(clip.asset).existsSync(), isTrue, reason: clip.asset);
      expect(File(clip.poster).existsSync(), isTrue, reason: clip.poster);
    }
  });

  test('كل حالة تبقى متكررة حتى ينتقل الدرس إلى حالة أخرى', () {
    for (final pose in SalehPose.values) {
      expect(SalehVideoClips.forPose(pose).loop, isTrue, reason: pose.name);
    }
  });
}

