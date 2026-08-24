import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../core/design/widgets/app_card.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/models/timeline_event.dart';
import '../scene_registry.dart';
import '../writing/letter_strokes.dart';
import '../writing/writing_canvases.dart';

/// مشهد الشرح — إثبات التزامن الكامل بين كلام صالح والمحتوى:
/// «انظر» → يظهر الحرف ويشير صالح، «ثاء» → ينبض الحرف،
/// «انظر كيف نكتب» → يُرسم المسار تدريجيًا، ثم يظهر مثال الكلمة.
class ExplanationScene extends StatefulWidget {
  const ExplanationScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  State<ExplanationScene> createState() => _ExplanationSceneState();
}

class _ExplanationSceneState extends State<ExplanationScene>
    with TickerProviderStateMixin {
  StreamSubscription<TimelineEvent>? _sub;

  // عناصر الشرح الأساسية ظاهرة من البداية مثل نموذج الواجهة المرجعي،
  // بينما تبقى أحداث الخط الزمني مسؤولة عن النبض والرسم.
  bool _letterVisible = true;
  bool _exampleVisible = true;
  bool _exampleHighlight = true;
  bool _drawing = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppDurations.pulse,
  );

  late final List<StrokeSpec> _strokes = StrokeSpec.listFromJson(
    // مسار الرسم التوضيحي يُشارك مع مشهد الكتابة إن وُجد في بياناته،
    // وإلا نكتفي بعرض الحرف نصًا.
    widget.scene.data['strokes'] as List?,
  );

  @override
  void initState() {
    super.initState();
    _sub = widget.api.channel.events.listen(_onEvent);
  }

  void _onEvent(TimelineEvent event) {
    if (!mounted) return;
    switch (event.action) {
      case TimelineAction.show:
        setState(() {
          if (event.target == 'letter') _letterVisible = true;
          if (event.target == 'example') _exampleVisible = true;
        });
        break;
      case TimelineAction.hide:
        setState(() {
          if (event.target == 'letter') _letterVisible = false;
          if (event.target == 'example') _exampleVisible = false;
        });
        break;
      case TimelineAction.pulse:
        _pulse.forward(from: 0).then((_) => _pulse.reverse());
        break;
      case TimelineAction.highlight:
        setState(() => _exampleHighlight = true);
        break;
      case TimelineAction.drawPath:
        setState(() => _drawing = true);
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.scene.data['letter'] as String? ?? '';
    final compact = MediaQuery.sizeOf(context).height < 760;
    final example =
        (widget.scene.data['example'] as Map<String, dynamic>?) ?? const {};

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // الحرف الكبير
              Expanded(
                flex: 3,
                child: AnimatedOpacity(
                  duration: AppDurations.normal,
                  opacity: _letterVisible ? 1 : 0,
                  child: AnimatedScale(
                    duration: AppDurations.normal,
                    scale: _letterVisible ? 1 : 0.6,
                    curve: Curves.easeOutBack,
                    child: _drawing && _strokes.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: WatchLetterAnimation(strokes: _strokes),
                          )
                        : Center(
                            child: ScaleTransition(
                              scale: Tween(begin: 1.0, end: 1.18).animate(
                                CurvedAnimation(
                                    parent: _pulse, curve: Curves.easeOut),
                              ),
                              child: Text(
                                letter,
                                style: AppTypography.letterHero.copyWith(
                                  fontSize: compact ? 108 : null,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.highlight
                                          .withValues(alpha: 0.6),
                                      blurRadius: _pulse.value * 40,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              // مثال الكلمة
              Expanded(
                flex: 2,
                child: AnimatedOpacity(
                  duration: AppDurations.normal,
                  opacity: _exampleVisible ? 1 : 0,
                  child: AnimatedSlide(
                    duration: AppDurations.normal,
                    offset:
                        _exampleVisible ? Offset.zero : const Offset(0, 0.2),
                    child: Center(
                      child: AppCard(
                        padding: EdgeInsets.all(compact ? 10 : AppSpacing.lg),
                        borderColor:
                            _exampleHighlight ? AppColors.highlight : null,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(example['emoji'] as String? ?? '',
                                style: TextStyle(fontSize: compact ? 48 : 80)),
                            SizedBox(height: compact ? 3 : AppSpacing.sm),
                            _HighlightedWord(
                              word: example['word'] as String? ?? '',
                              prefix:
                                  example['highlightPrefix'] as String? ?? '',
                              highlighted: _exampleHighlight,
                              compact: compact,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LessonAction(
                icon: Icons.volume_up_rounded,
                color: AppColors.brandGreen,
              ),
              SizedBox(width: AppSpacing.md),
              _LessonAction(
                icon: Icons.mic_rounded,
                color: AppColors.brandYellow,
              ),
              SizedBox(width: AppSpacing.md),
              _LessonAction(
                icon: Icons.videocam_rounded,
                color: AppColors.accentBlue,
              ),
            ],
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: widget.api.channel.scriptFinished,
          builder: (context, finished, _) => AnimatedOpacity(
            duration: AppDurations.normal,
            opacity: finished ? 1 : 0,
            child: LessonActionButton(
              label: 'فهمت!',
              icon: Icons.thumb_up_alt_rounded,
              onPressed: finished ? widget.api.completeScene : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _LessonAction extends StatelessWidget {
  const _LessonAction({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;
    final size = compact ? 42.0 : 54.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, offset: Offset(0, 4), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: compact ? 22 : 29),
    );
  }
}

/// كلمة يُبرز أولها (حرف الدرس) بلون مختلف — مثل «ثوم».
class _HighlightedWord extends StatelessWidget {
  const _HighlightedWord({
    required this.word,
    required this.prefix,
    required this.highlighted,
    required this.compact,
  });

  final String word;
  final String prefix;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rest = word.startsWith(prefix) && prefix.isNotEmpty
        ? word.substring(prefix.length)
        : word;
    return Text.rich(
      TextSpan(
        children: [
          if (word.startsWith(prefix) && prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: AppTypography.display.copyWith(
                fontSize: compact ? 34 : 48,
                color: highlighted ? AppColors.letterPrimary : AppColors.ink,
              ),
            ),
          TextSpan(
            text: rest,
            style: AppTypography.display.copyWith(fontSize: compact ? 34 : 48),
          ),
        ],
      ),
      textDirection: TextDirection.rtl,
    );
  }
}

