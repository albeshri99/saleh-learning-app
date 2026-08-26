import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';
import '../writing/handwriting_validator.dart';
import '../writing/letter_trace_template.dart';
import '../writing/letter_strokes.dart';
import '../writing/writing_canvases.dart';

/// مشهد الكتابة — بالدليل أو حرًا حسب نوع المشهد وإعدادات المحتوى.
/// عدد المحاولات يأتي من [WritingConfig] في بيانات المشهد، لا من الكود.
class WritingScene extends ConsumerStatefulWidget {
  const WritingScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<WritingScene> createState() => _WritingSceneState();
}

class _WritingSceneState extends ConsumerState<WritingScene> {
  late final WritingConfig _config = WritingConfig.fromJson(
    (widget.scene.data['writing'] as Map<String, dynamic>?) ?? const {},
  );
  late final LetterTraceTemplate? _traceTemplate = LetterTraceTemplate.fromId(
      widget.scene.data['traceTemplateId'] as String?);
  late final List<StrokeSpec> _strokes = _traceTemplate?.strokes ??
      StrokeSpec.listFromJson(widget.scene.data['strokes'] as List?);
  late final bool _guided = widget.scene.type == SceneType.guidedWriting;

  final _freeCanvasKey = GlobalKey<FreeWritingCanvasState>();

  int _attempt = 1;
  bool _attemptDone = false;
  bool _hasFreeInk = false;
  String? _freeValidationMessage;
  bool _freeValidationPassed = false;
  bool _validatingFree = false;
  bool _showDemo = false;
  int _demoPass = 0;

  @override
  void initState() {
    super.initState();
    _showDemo = _guided;
  }

  int get _totalAttempts =>
      _guided ? _config.guidedAttempts : _config.freeAttempts;

  void _finishAttempt() {
    widget.api.recordAttempt();
    if (_attempt >= _totalAttempts) {
      widget.api.completeScene();
    } else {
      // أوقف حركة التشجيع السابقة؛ صوت «مرة أخرى» سيحوّل صالح تلقائيًا
      // إلى talking، ثم يعود طبيعيًا عند نهاية الصوت.
      widget.api.triggerSaleh('idle');
      setState(() {
        _attempt++;
        _attemptDone = false;
        _hasFreeInk = false;
        _freeValidationMessage = null;
        _freeValidationPassed = false;
        _validatingFree = false;
      });
      _freeCanvasKey.currentState?.clear();
      final againAudio = widget.scene.data['againAudio'] as String?;
      if (againAudio != null) {
        unawaited(ref.read(audioServiceProvider).play(againAudio));
      }
    }
  }

  void _guidedCompleted() {
    if (_attemptDone) return;
    setState(() => _attemptDone = true);
    widget.api.triggerSaleh('happyOnce');
    final praiseAudio = widget.scene.data['guidedPraiseAudio'] as String?;
    if (praiseAudio != null) {
      unawaited(ref.read(audioServiceProvider).play(praiseAudio));
    }
  }

  Future<void> _validateFreeWriting() async {
    if (_validatingFree) return;
    final canvas = _freeCanvasKey.currentState;
    if (canvas == null || !canvas.hasInk) {
      widget.api.completeScene();
      return;
    }
    if (_traceTemplate?.id != alifFathaVideoTemplate.id) {
      _finishAttempt();
      return;
    }

    final result = validateAlifFathaChildFriendly(canvas.sample);
    if (result.isValid) {
      const message = 'أحسنت، لقد كتبت حرف الألف بطريقة صحيحة ممتازة';
      setState(() {
        _validatingFree = true;
        _freeValidationPassed = true;
        _freeValidationMessage = message;
      });
      widget.api.triggerSaleh('happyOnce');
      final successAudio = widget.scene.data['successAudio'] as String?;
      try {
        if (successAudio != null) {
          await ref.read(audioServiceProvider).play(successAudio);
        }
      } finally {
        if (mounted) _finishAttempt();
      }
      return;
    }
    widget.api.recordAttempt();
    setState(() {
      _freeValidationPassed = false;
      _freeValidationMessage = switch (result.reason) {
        'missingParts' => 'اكتب جسم الألف، وأضف العلامة فوقه',
        'bodyShape' => 'اكتب خط الألف بشكل واضح من الأعلى إلى الأسفل',
        _ => 'حاول مرة أخرى، واكتب حرف أَ بوضوح',
      };
    });
  }

  void _finishDemoPass() {
    if (!mounted) return;
    if (_demoPass >= 1) {
      setState(() => _showDemo = false);
    } else {
      setState(() => _demoPass++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.scene.data['letter'] as String? ?? 'ث';
    final compact = MediaQuery.sizeOf(context).height < 760;
    final showHeader = _showDemo || !_guided;
    final actionHeight = compact ? 72.0 : 80.0;
    return Column(
      children: [
        if (showHeader)
          SizedBox(
            height: compact ? 36 : 52,
            child: Center(
              child: Text(
                _showDemo ? 'شاهد كيف نكتب الحرف' : 'اكتب الحرف بنفسك',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.subtitle.copyWith(
                  fontSize: compact ? 18 : null,
                ),
              ),
            ),
          ),
        SizedBox(height: showHeader ? AppSpacing.sm : 4),
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
                if (_showDemo)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: WatchLetterAnimation(
                      key: ValueKey('alif_demo_$_demoPass'),
                      letter: letter,
                      strokes: _strokes,
                      traceTemplate: _traceTemplate,
                      duration: const Duration(milliseconds: 5200),
                      onFinished: _finishDemoPass,
                    ),
                  )
                else if (_guided)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: _attemptDone
                        ? _CompletedLetter(
                            letter: letter,
                            strokes: _strokes,
                            traceTemplate: _traceTemplate,
                          )
                        : GuidedTracingCanvas(
                            key: ValueKey('trace_$_attempt'),
                            letter: letter,
                            strokes: _strokes,
                            traceTemplate: _traceTemplate,
                            onStrokeCompleted: (_) {},
                            onAllCompleted: _guidedCompleted,
                          ),
                  )
                else
                  FreeWritingCanvas(
                    key: _freeCanvasKey,
                    onInkChanged: (hasInk) {
                      if (!_validatingFree &&
                          (_hasFreeInk != hasInk ||
                              _freeValidationMessage != null)) {
                        setState(() {
                          _hasFreeInk = hasInk;
                          _freeValidationMessage = null;
                          _freeValidationPassed = false;
                        });
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 4 : AppSpacing.sm),
        if (!_guided && _freeValidationMessage != null) ...[
          Text(
            _freeValidationMessage!,
            key: const ValueKey('free-writing-validation-message'),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: _freeValidationPassed
                  ? AppColors.successDark
                  : AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(
          height: actionHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_guided) ...[
                LessonActionButton(
                  label: 'مسح',
                  icon: Icons.refresh_rounded,
                  onPressed: () {
                    if (_validatingFree) return;
                    _freeCanvasKey.currentState?.clear();
                    setState(() {
                      _hasFreeInk = false;
                      _freeValidationMessage = null;
                      _freeValidationPassed = false;
                    });
                  },
                ),
                const SizedBox(width: AppSpacing.md),
                LessonActionButton(
                  label: _hasFreeInk ? 'انتهيت' : 'تخطي',
                  icon: _hasFreeInk
                      ? Icons.check_rounded
                      : Icons.skip_next_rounded,
                  onPressed: _validatingFree
                      ? null
                      : (_hasFreeInk
                          ? () => _validateFreeWriting()
                          : widget.api.completeScene),
                ),
              ] else if (!_showDemo && _attemptDone)
                LessonActionButton(
                  label: _attempt >= _totalAttempts ? 'أحسنت!' : 'مرة أخرى',
                  icon: Icons.check_rounded,
                  onPressed: _finishAttempt,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// عرض الحرف مكتملًا باللون الأخضر بعد نجاح التتبع.
class _CompletedLetter extends StatefulWidget {
  const _CompletedLetter({
    required this.letter,
    required this.strokes,
    this.traceTemplate,
  });

  final String letter;
  final List<StrokeSpec> strokes;
  final LetterTraceTemplate? traceTemplate;

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
      child: CompletedTracingCanvas(
        letter: widget.letter,
        strokes: widget.strokes,
        traceTemplate: widget.traceTemplate,
      ),
    );
  }
}
