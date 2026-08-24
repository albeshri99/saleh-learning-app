import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';

/// التقويم: أسئلة اختيار من متعدد تأتي كاملة من المحتوى.
/// كل إجابة تُسجل في المتحكم لتدخل في حساب الإتقان.
class McqScene extends StatefulWidget {
  const McqScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  State<McqScene> createState() => _McqSceneState();
}

class _McqSceneState extends State<McqScene> {
  late final List<Map<String, dynamic>> _questions =
      ((widget.scene.data['questions'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

  int _questionIndex = 0;
  int? _selected;
  bool _answered = false;

  Map<String, dynamic> get _q => _questions[_questionIndex];

  List<String> get _options => (_q['options'] as List).cast<String>();

  int get _correctIndex => (_q['correctIndex'] as num? ?? 0).toInt();

  void _choose(int index) {
    if (_answered) return;
    setState(() {
      _selected = index;
      _answered = true;
    });
    widget.api.recordAttempt();
    final correct = index == _correctIndex;
    widget.api.recordAnswer(correct: correct);
    widget.api.triggerSaleh(correct ? 'happy' : 'surprised');
  }

  void _next() {
    if (_questionIndex + 1 >= _questions.length) {
      widget.api.completeScene();
    } else {
      setState(() {
        _questionIndex++;
        _selected = null;
        _answered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Center(
        child: AppButton(label: 'متابعة', onPressed: widget.api.completeScene),
      );
    }
    final correct = _selected == _correctIndex;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        return Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'سؤال ${_questionIndex + 1} من ${_questions.length}',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _q['prompt'] as String? ?? '',
                      style: AppTypography.title,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: compact ? 8 : AppSpacing.lg),
                    Row(
                      children: [
                        for (var i = 0; i < _options.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 4 : 7,
                              ),
                              child: _OptionCard(
                                label: _options[i],
                                compact: compact,
                                state: !_answered
                                    ? _OptionState.idle
                                    : i == _correctIndex
                                        ? _OptionState.correct
                                        : i == _selected
                                            ? _OptionState.wrong
                                            : _OptionState.dimmed,
                                onTap: () => _choose(i),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedOpacity(
              duration: AppDurations.normal,
              opacity: _answered ? 1 : 0,
              child: Column(
                children: [
                  Text(
                    _answered
                        ? (correct
                            ? 'إجابة صحيحة! 🎉'
                            : 'الإجابة الصحيحة بالأخضر')
                        : '',
                    style: AppTypography.subtitle.copyWith(
                      color: correct ? AppColors.successDark : AppColors.danger,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : AppSpacing.sm),
                  LessonActionButton(
                    label: _questionIndex + 1 >= _questions.length
                        ? 'إنهاء التقويم'
                        : 'السؤال التالي',
                    icon: Icons.arrow_back_rounded,
                    onPressed: _answered ? _next : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.state,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final _OptionState state;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color border;
    final Color bg;
    switch (state) {
      case _OptionState.correct:
        border = AppColors.success;
        bg = const Color(0xFFE8F7E9);
        break;
      case _OptionState.wrong:
        border = AppColors.danger;
        bg = const Color(0xFFFDEAEA);
        break;
      case _OptionState.dimmed:
        border = AppColors.letterGuide;
        bg = AppColors.surface;
        break;
      case _OptionState.idle:
        border = AppColors.letterGuide;
        bg = AppColors.surface;
        break;
    }
    return AnimatedScale(
      duration: AppDurations.fast,
      scale: state == _OptionState.correct ? 1.06 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(
              minWidth: compact ? 58 : 82,
              minHeight: compact ? 68 : 92,
            ),
            padding: EdgeInsets.all(compact ? 6 : AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: border, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTypography.display.copyWith(
                fontSize: compact ? 34 : 42,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

