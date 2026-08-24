import 'package:flutter/material.dart';

import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';

/// مشهد الترحيب: صالح يرحب بالطفل، وزر البدء متاح فورًا للتخطي المباشر.
class WelcomeScene extends StatelessWidget {
  const WelcomeScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: Center(child: Text('🌟', style: TextStyle(fontSize: 78))),
        ),
        LessonActionButton(
          label: 'هيا نبدأ!',
          icon: Icons.play_arrow_rounded,
          onPressed: api.completeScene,
        ),
      ],
    );
  }
}

