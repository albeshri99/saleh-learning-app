import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../core/design/widgets/app_card.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';

/// المراجعة القبلية: تذكيرية فقط — صالح يعرض الحروف السابقة بأمثلتها،
/// ولا يُطلب من الطفل أي إجابة.
class ReviewScene extends StatelessWidget {
  const ReviewScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  Widget build(BuildContext context) {
    final items =
        (scene.data['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 280;
      final cardWidth = compact
          ? ((constraints.maxWidth - 24) / items.length).clamp(72.0, 150.0)
          : 150.0;
      final cards = [
        for (final item in items)
          SizedBox(
            width: cardWidth,
            child: AppCard(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : AppSpacing.md,
                vertical: compact ? 5 : AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item['letter'] as String? ?? '',
                      style: AppTypography.display.copyWith(
                        color: AppColors.letterPrimary,
                        fontSize: compact ? 30 : null,
                        height: 1,
                      )),
                  Text(item['emoji'] as String? ?? '',
                      style:
                          TextStyle(fontSize: compact ? 27 : 44, height: 1.1)),
                  Text(item['word'] as String? ?? '',
                      maxLines: 1,
                      style: AppTypography.subtitle.copyWith(
                        fontSize: compact ? 14 : null,
                      )),
                ],
              ),
            ),
          ),
      ];

      return Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  if (index > 0) SizedBox(width: compact ? 7 : AppSpacing.lg),
                  Flexible(child: cards[index]),
                ],
              ],
            ),
            SizedBox(height: compact ? 5 : AppSpacing.lg),
          ValueListenableBuilder<bool>(
            valueListenable: api.channel.scriptFinished,
            builder: (context, finished, _) => SizedBox(
              height: compact ? 48 : 58,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AppButton(
                label: 'تذكرتها!',
                icon: Icons.check_rounded,
                color: AppColors.success,
                shadowColor: AppColors.successDark,
                onPressed: finished ? api.completeScene : null,
                ),
              ),
            ),
          ),
          ],
        ),
      );
    });
  }
}

