import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';

/// مشهد النجاح: نجوم متتابعة + احتفال صالح + العودة للرئيسية.
class SuccessScene extends StatefulWidget {
  const SuccessScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  State<SuccessScene> createState() => _SuccessSceneState();
}

class _SuccessSceneState extends State<SuccessScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stars = (widget.scene.data['stars'] as num? ?? 3).toInt();
    final compact = MediaQuery.sizeOf(context).height < 760;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < stars; i++)
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _c,
                          curve: Interval(
                            i / stars,
                            (i + 1) / stars,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(compact ? 2 : AppSpacing.sm),
                          child: Icon(
                            Icons.star_rounded,
                            color: AppColors.starGold,
                            size: compact ? 36 : 96,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : AppSpacing.lg),
                Text(
                  'أتقنتَ الدرس!',
                  style: AppTypography.title
                      .copyWith(fontSize: compact ? 24 : null),
                ),
              ],
            ),
          ),
        ),
        LessonActionButton(
          label: 'العودة للرئيسية',
          icon: Icons.home_rounded,
          onPressed: () {
            widget.api.completeScene(); // ينهي الدرس ويحفظ الإتقان
            context.go('/');
          },
        ),
      ],
    );
  }
}

