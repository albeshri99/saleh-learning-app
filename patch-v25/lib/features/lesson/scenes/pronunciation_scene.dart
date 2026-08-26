import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';

enum _MicState { idle, listening, correct, tryAgain }

/// تدريب النطق: الميكروفون يعمل هنا فقط (وليس في الشرح).
/// التقييم عبر التعرف الحقيقي على الكلام ثم تغذية راجعة من صالح.
class PronunciationScene extends ConsumerStatefulWidget {
  const PronunciationScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<PronunciationScene> createState() => _PronunciationSceneState();
}

class _PronunciationSceneState extends ConsumerState<PronunciationScene> {
  _MicState _state = _MicState.idle;

  Future<void> _playFeedback(bool correct) async {
    final key = correct ? 'successAudio' : 'retryAudio';
    final asset = widget.scene.data[key] as String?;
    if (asset != null) await ref.read(audioServiceProvider).play(asset);
  }

  Future<void> _listen() async {
    if (_state == _MicState.listening) return;
    await ref.read(audioServiceProvider).stop();
    if (!mounted) return;
    setState(() => _state = _MicState.listening);
    widget.api.recordAttempt();
    final expected = widget.scene.data['expected'] as String? ?? '';
    final result = await ref.read(speechServiceProvider).listenFor(expected);
    if (!mounted) return;
    setState(
        () => _state = result.correct ? _MicState.correct : _MicState.tryAgain);
    widget.api.recordAnswer(correct: result.correct);
    widget.api.triggerSaleh(result.correct ? 'happy' : 'surprised');
    await _playFeedback(result.correct);
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.scene.data['letter'] as String? ?? '';
    final spokenLetter = widget.scene.data['spokenLetter'] as String? ?? letter;
    final compact = MediaQuery.sizeOf(context).height < 760;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: compact ? 10 : AppSpacing.lg),
            child: Align(
              alignment: const Alignment(0, -0.25),
              child: SizedBox(
                width: compact ? 108 : 150,
                height: compact ? 122 : 164,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    letter,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.letterHero.copyWith(
                      fontSize: compact ? 72 : 112,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 6 : AppSpacing.md),
        if (_state == _MicState.correct) ...[
          Text(
            'أحسنت، نطقك رائع! 🎉',
            style: AppTypography.title.copyWith(color: AppColors.successDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          LessonActionButton(
            label: 'متابعة',
            icon: Icons.arrow_back_rounded,
            onPressed: widget.api.completeScene,
          ),
        ] else ...[
          if (_state == _MicState.tryAgain)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'لنحاول مرة أخرى!',
                style: AppTypography.title.copyWith(color: AppColors.danger),
              ),
            ),
          _MicButton(
            listening: _state == _MicState.listening,
            onTap: _state == _MicState.listening ? null : _listen,
          ),
          SizedBox(height: compact ? 6 : AppSpacing.md),
          Text(
            _state == _MicState.listening
                ? 'أسمعك الآن... انطق $spokenLetter'
                : 'اضغط وانطق $spokenLetter',
            style: AppTypography.subtitle.copyWith(
              fontSize: compact ? 17 : null,
            ),
          ),
          SizedBox(height: compact ? 6 : AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback? onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.9,
    upperBound: 1.1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;
    final size = compact ? 76.0 : 110.0;
    return ScaleTransition(
      scale: widget.listening ? _c : const AlwaysStoppedAnimation(1),
      child: Material(
        color: widget.listening ? AppColors.danger : AppColors.success,
        shape: const CircleBorder(),
        elevation: 6,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              widget.listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: compact ? 38 : 56,
            ),
          ),
        ),
      ),
    );
  }
}
