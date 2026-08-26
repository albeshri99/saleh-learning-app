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

/// التقويم: أسئلة اختيار من متعدد تأتي كاملة من المحتوى.
/// كل إجابة تُسجل في المتحكم لتدخل في حساب الإتقان.
class McqScene extends ConsumerStatefulWidget {
  const McqScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<McqScene> createState() => _McqSceneState();
}

class _McqSceneState extends ConsumerState<McqScene> {
  late final List<Map<String, dynamic>> _questions =
      ((widget.scene.data['questions'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

  int _questionIndex = 0;
  int? _selected;
  bool _answered = false;
  bool _moving = false;

  Map<String, dynamic> get _q => _questions[_questionIndex];

  List<String> get _options => (_q['options'] as List).cast<String>();

  List<String> get _optionEmojis =>
      ((_q['optionEmojis'] as List?) ?? const []).cast<String>();

  List<String> get _optionImages =>
      ((_q['optionImages'] as List?) ?? const []).cast<String>();

  int get _correctIndex => (_q['correctIndex'] as num? ?? 0).toInt();

  bool get _showPrompt => _q['showPrompt'] as bool? ?? true;

  Future<void> _choose(int index) async {
    if (_answered) return;
    setState(() {
      _selected = index;
      _answered = true;
    });
    widget.api.recordAttempt();
    final correct = index == _correctIndex;
    widget.api.recordAnswer(correct: correct);
    widget.api.triggerSaleh(correct ? 'happy' : 'surprised');
    final audio =
        widget.scene.data[correct ? 'successAudio' : 'retryAudio'] as String?;
    final feedbackPlayback = audio == null
        ? Future<void>.value()
        : ref.read(audioServiceProvider).play(audio);
    if (correct) {
      // الانتقال متاح فورًا؛ لا نربط الزر بمدة ملف الصوت أو حركة صالح.
      unawaited(feedbackPlayback);
      return;
    }
    await feedbackPlayback;
    if (!mounted || correct) return;
    // الإجابة الخاطئة لا تكشف الحل ولا تقفل السؤال؛ يسمع الطفل التشجيع
    // ثم يستطيع المحاولة مرة أخرى مباشرة.
    setState(() {
      _selected = null;
      _answered = false;
    });
  }

  Future<void> _next() async {
    if (_moving || !_answered) return;
    _moving = true;
    if (_questionIndex + 1 >= _questions.length) {
      widget.api.completeScene();
    } else {
      setState(() {
        _questionIndex++;
        _selected = null;
        _answered = false;
      });
      final secondAudio = widget.scene.data['secondAudio'] as String?;
      if (secondAudio != null) {
        unawaited(ref.read(audioServiceProvider).play(secondAudio));
      }
    }
    _moving = false;
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
        final compact = constraints.maxHeight < 420;
        return Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: compact ? 0 : 40),
                    if (_showPrompt) ...[
                      Text(
                        _q['prompt'] as String? ?? '',
                        style: AppTypography.title.copyWith(
                          fontSize: compact ? 22 : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: compact ? 3 : AppSpacing.lg),
                    ],
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        for (var i = 0; i < _options.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 4 : 7,
                              ),
                              child: _OptionCard(
                                label: _options[i],
                                imageAsset: i < _optionImages.length &&
                                        _optionImages[i].trim().isNotEmpty
                                    ? _optionImages[i]
                                    : null,
                                emoji: i < _optionEmojis.length
                                    ? _optionEmojis[i]
                                    : null,
                                highlightFirst: _questionIndex == 1,
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
            SizedBox(
              height: compact ? 86 : 104,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: compact ? 28 : 36,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _answered ? 1 : 0,
                        child: Text(
                          _answered
                              ? (correct ? 'إجابة صحيحة! 🎉' : 'حاول مرة أخرى')
                              : '',
                          style: AppTypography.subtitle.copyWith(
                            color: correct
                                ? AppColors.successDark
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _answered && correct ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_answered || !correct,
                      child: LessonActionButton(
                        key: ValueKey('mcq_action_$_questionIndex'),
                        label: _questionIndex + 1 >= _questions.length
                            ? 'إنهاء التقويم'
                            : 'السؤال التالي',
                        icon: Icons.arrow_back_rounded,
                        onPressed: _next,
                      ),
                    ),
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
    required this.imageAsset,
    required this.emoji,
    required this.highlightFirst,
    required this.state,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final String? imageAsset;
  final String? emoji;
  final bool highlightFirst;
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
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onTap(),
        child: Container(
          constraints: BoxConstraints(
            minWidth: compact ? 58 : 82,
            minHeight: compact ? 46 : 92,
          ),
          padding: EdgeInsets.all(compact ? 2 : AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: border, width: 3),
          ),
          alignment: Alignment.center,
          child: imageAsset == null && emoji == null
              ? SizedBox(
                  height: compact ? 44 : 78,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 10 : 14,
                      compact ? 8 : 11,
                      compact ? 10 : 14,
                      compact ? 5 : 8,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        textDirection: TextDirection.rtl,
                        style: AppTypography.display.copyWith(
                          fontSize: compact ? 28 : 40,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: compact ? 60 : 92,
                      width: double.infinity,
                      child: imageAsset != null
                          ? Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 8 : 12,
                                vertical: compact ? 4 : 6,
                              ),
                              child: Transform.scale(
                                // ملف الأسد يحتوي هامشًا شفافًا أكبر من بقية
                                // الحيوانات؛ نصححه بصريًا من دون قص الصورة.
                                scale: imageAsset!.endsWith('alif_lion.png')
                                    ? 1.55
                                    : 1,
                                child: Image.asset(
                                  imageAsset!,
                                  key: ValueKey(
                                    'assessment-option-image-$imageAsset',
                                  ),
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            )
                          : Text(
                              emoji!,
                              style: TextStyle(fontSize: compact ? 20 : 42),
                            ),
                    ),
                    _OptionWord(
                      word: label,
                      highlightFirst: highlightFirst,
                      compact: compact,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OptionWord extends StatelessWidget {
  const _OptionWord({
    required this.word,
    required this.highlightFirst,
    required this.compact,
  });

  final String word;
  final bool highlightFirst;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final codes = word.runes.toList();
    var prefixLength = codes.isEmpty ? 0 : 1;
    if (codes.length > 1 && codes[1] >= 0x064B && codes[1] <= 0x065F) {
      prefixLength = 2;
    }
    final prefix = String.fromCharCodes(codes.take(prefixLength));
    final rest = String.fromCharCodes(codes.skip(prefixLength));
    final style = AppTypography.subtitle.copyWith(
      fontSize: compact ? 16 : 22,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: prefix,
            style: style.copyWith(
              color: highlightFirst ? AppColors.letterPrimary : AppColors.ink,
            ),
          ),
          TextSpan(text: rest, style: style),
        ],
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}
