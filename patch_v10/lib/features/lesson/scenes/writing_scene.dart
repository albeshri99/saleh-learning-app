import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';
import '../writing/letter_strokes.dart';
import '../writing/writing_canvases.dart';

/// مشهد الكتابة — بالدليل أو حرًا حسب نوع المشهد وإعدادات المحتوى.
/// عدد المحاولات يأتي من [WritingConfig] في بيانات المشهد، لا من الكود.
class WritingScene extends StatefulWidget {
  const WritingScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  State<WritingScene> createState() => _WritingSceneState();
}

class _WritingSceneState extends State<WritingScene> {
  late final WritingConfig _config = WritingConfig.fromJson(
    (widget.scene.data['writing'] as Map<String, dynamic>?) ?? const {},
  );
  late final List<StrokeSpec> _strokes =
      StrokeSpec.listFromJson(widget.scene.data['strokes'] as List?);
  late final bool _guided = widget.scene.type == SceneType.guidedWriting;

  final _freeCanvasKey = GlobalKey<FreeWritingCanvasState>();

  int _attempt = 1;
  bool _attemptDone = false;
  bool _hasFreeInk = false;

  int get _totalAttempts =>
      _guided ? _config.guidedAttempts : _config.freeAttempts;

  void _finishAttempt() {
    widget.api.recordAttempt();
    if (_attempt >= _totalAttempts) {
      widget.api.completeScene();
    } else {
      setState(() {
        _attempt++;
        _attemptDone = false;
        _hasFreeInk = false;
      });
      _freeCanvasKey.currentState?.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.scene.data['letter'] as String? ?? '';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _guided ? 'اكتب فوق المسار' : 'اكتب الحرف بنفسك',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.subtitle.copyWith(
                fontSize: MediaQuery.sizeOf(context).height < 760 ? 18 : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            for (var i = 1; i <= _totalAttempts; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i < _attempt || (i == _attempt && _attemptDone)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: AppColors.starGold,
                  size: MediaQuery.sizeOf(context).height < 760 ? 24 : 30,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.letterGuide, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (!_guided)
                  // مرجع صغير للحرف في ركن اللوح (بلا دليل على مساحة الكتابة)
                  PositionedDirectional(
                    top: AppSpacing.sm,
                    start: AppSpacing.md,
                    child: Text(
                      letter,
                      style: AppTypography.display
                          .copyWith(color: AppColors.letterGuide),
                    ),
                  ),
                if (_guided)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _attemptDone
                        ? _CompletedLetter(strokes: _strokes)
                        : GuidedTracingCanvas(
                            key: ValueKey('trace_$_attempt'),
                            strokes: _strokes,
                            onStrokeCompleted: (_) {},
                            onAllCompleted: () =>
                                setState(() => _attemptDone = true),
                          ),
                  )
                else
                  FreeWritingCanvas(
                    key: _freeCanvasKey,
                    onInkChanged: (hasInk) {
                      if (_hasFreeInk != hasInk) {
                        setState(() => _hasFreeInk = hasInk);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_guided) ...[
              LessonActionButton(
                label: 'مسح',
                icon: Icons.refresh_rounded,
                width: 118,
                color: AppColors.accentBlue,
                shadowColor: AppColors.skyDeep,
                onPressed: () {
                  _freeCanvasKey.currentState?.clear();
                  setState(() => _hasFreeInk = false);
                },
              ),
              const SizedBox(width: AppSpacing.md),
              LessonActionButton(
                label: _attempt >= _totalAttempts ? 'انتهيت!' : 'تم — التالي',
                icon: Icons.check_rounded,
                color: AppColors.success,
                shadowColor: AppColors.successDark,
                onPressed: _hasFreeInk ? _finishAttempt : null,
              ),
            ] else if (_attemptDone)
              LessonActionButton(
                label: _attempt >= _totalAttempts ? 'أحسنت!' : 'مرة أخرى',
                icon: Icons.check_rounded,
                color: AppColors.success,
                shadowColor: AppColors.successDark,
                onPressed: _finishAttempt,
              ),
          ],
        ),
      ],
    );
  }
}

/// عرض الحرف مكتملًا باللون الأخضر بعد نجاح التتبع.
class _CompletedLetter extends StatefulWidget {
  const _CompletedLetter({required this.strokes});

  final List<StrokeSpec> strokes;

  @override
  State<_CompletedLetter> createState() => _CompletedLetterState();
}

class _CompletedLetterState extends State<_CompletedLetter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: .95 * _glow.value),
              const Color(0x00FFFFFF),
            ],
            stops: const [.05, .72],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: .85 * _glow.value),
              blurRadius: 42 * _glow.value,
              spreadRadius: 12 * _glow.value,
            ),
          ],
        ),
        child: child,
      ),
      child: CustomPaint(
        painter: _AllDonePainter(widget.strokes),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AllDonePainter extends CustomPainter {
  _AllDonePainter(this.strokes);

  final List<StrokeSpec> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final done = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = (size.shortestSide * 0.13).clamp(18.0, 34.0)
      ..color = AppColors.letterTraced;
    for (final s in strokes) {
      final path = s.scaledPath(size);
      if (s.kind == StrokeKind.dot) {
        canvas.drawPath(path, Paint()..color = AppColors.letterTraced);
      } else {
        canvas.drawPath(path, done);
      }
    }
  }

  @override
  bool shouldRepaint(_AllDonePainter old) => false;
}

