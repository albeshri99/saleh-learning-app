import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';

/// مشهد الترحيب: صالح يرحب بالطفل باسمه، وزر البدء يظهر بعد انتهاء كلامه.
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
        ValueListenableBuilder<bool>(
          valueListenable: api.channel.scriptFinished,
          builder: (context, finished, _) => LessonActionButton(
            label: 'هيا نبدأ!',
            icon: Icons.play_arrow_rounded,
            color: AppColors.success,
            shadowColor: AppColors.successDark,
            onPressed: finished ? api.completeScene : null,
          ),
        ),
      ],
    );
  }
}

