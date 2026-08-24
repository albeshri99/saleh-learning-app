import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../../../services/audio/audio_service.dart';
import '../scene_registry.dart';

/// مشهد الأنشودة: الوسيط (صوت/فيديو) يأتي من المحتوى.
/// يشغَّل الصوت عبر AudioService مع مؤشر تقدم،
/// وينتقل تلقائيًا عند الانتهاء.
class NasheedScene extends ConsumerStatefulWidget {
  const NasheedScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<NasheedScene> createState() => _NasheedSceneState();
}

class _NasheedSceneState extends ConsumerState<NasheedScene>
    with SingleTickerProviderStateMixin {
  late final Duration _length = Duration(
    milliseconds:
        (((widget.scene.data['durationSec'] as num?) ?? 8) * 1000).round(),
  );
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: _length);

  /// يُحتفظ بالخدمة منذ initState: قراءة `ref` داخل dispose ترمي
  /// «Cannot use "ref" after the widget was disposed» عند مغادرة المشهد،
  /// لأن ConsumerState يبطل الـ ref قبل استدعاء dispose.
  late final AudioService _audio = ref.read(audioServiceProvider);

  @override
  void initState() {
    super.initState();
    // ننتظر تقديم صالح ثم نشغل الأنشودة.
    widget.api.channel.scriptFinished.addListener(_maybeStart);
  }

  void _maybeStart() {
    if (!widget.api.channel.scriptFinished.value || _progress.isAnimating) {
      return;
    }
    final media = widget.scene.data['media'] as String?;
    if (media != null) unawaited(_audio.play(media));
    _progress.forward().whenComplete(() {
      if (mounted) widget.api.completeScene();
    });
  }

  @override
  void dispose() {
    widget.api.channel.scriptFinished.removeListener(_maybeStart);
    _progress.dispose();
    unawaited(_audio.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) => Transform.scale(
                    scale: 1 +
                        0.08 *
                            (_progress.isAnimating ? 1 : 0) *
                            (0.5 +
                                0.5 *
                                    (1 -
                                        (_progress.value * 8 % 1 - 0.5).abs() *
                                            2)),
                    child: Text(
                      '🎵',
                      style: TextStyle(fontSize: compact ? 68 : 110),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 8 : AppSpacing.lg),
                const Text('أنشودة حرف الثاء', style: AppTypography.title),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress.value,
                        minHeight: 12,
                        backgroundColor: AppColors.letterGuide,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        LessonActionButton(
          label: 'تخطي',
          icon: Icons.skip_next_rounded,
          onPressed: widget.api.completeScene,
        ),
      ],
    );
  }
}

