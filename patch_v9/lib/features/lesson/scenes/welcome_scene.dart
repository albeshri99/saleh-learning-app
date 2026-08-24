import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🌟', style: TextStyle(fontSize: 96)),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: ValueListenableBuilder<bool>(
            valueListenable: api.channel.scriptFinished,
            builder: (context, finished, _) => AppButton(
              label: 'هيا نبدأ!',
              icon: Icons.play_arrow_rounded,
              minWidth: 138,
              minHeight: 48,
              iconSize: 23,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              color: AppColors.success,
              shadowColor: AppColors.successDark,
              onPressed: finished ? api.completeScene : null,
            ),
          ),
        ),
      ],
    );
  }
}
