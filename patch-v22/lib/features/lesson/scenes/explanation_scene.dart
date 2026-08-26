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
  bool _exampleVisible = false;
  bool _exampleHighlight = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppDurations.pulse,
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
        _pulse.forward(from: 0).then((_) => _pulse.reverse());
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              // يبدأ الألف في مركز السبورة تمامًا. عند ظهور المثال يتحرك
              // قليلًا إلى اليمين ليترك للصورة والكلمة مساحةً يساره.
              AnimatedAlign(
                duration: AppDurations.normal,
                curve: Curves.easeInOutCubic,
                alignment: _exampleVisible
                    ? const Alignment(.48, .28)
                    : const Alignment(0, .28),
                child: SizedBox(
                  width: compact ? 180 : 250,
                  child: AnimatedOpacity(
                    duration: AppDurations.normal,
                    opacity: _letterVisible ? 1 : 0,
                    child: AnimatedScale(
                      duration: AppDurations.normal,
                      scale: _letterVisible ? 1 : .6,
                      curve: Curves.easeOutBack,
                      child: Center(
                        child: ScaleTransition(
                          scale: Tween(begin: 1.0, end: 1.18).animate(
                            CurvedAnimation(
                              parent: _pulse,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: _LessonLetterGlyph(
                            letter: letter,
                            compact: compact,
                            glow: _pulse.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: .48,
                  child: AnimatedOpacity(
                    duration: AppDurations.normal,
                    opacity: _exampleVisible ? 1 : 0,
                    child: AnimatedSlide(
                      duration: AppDurations.normal,
                      offset:
                          _exampleVisible ? Offset.zero : const Offset(-.12, 0),
                      child: Center(
                        child: AppCard(
                          padding: EdgeInsets.all(compact ? 8 : AppSpacing.md),
                          borderColor:
                              _exampleHighlight ? AppColors.highlight : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                example['emoji'] as String? ?? '',
                                style: TextStyle(fontSize: compact ? 48 : 76),
                              ),
                              SizedBox(width: compact ? 7 : AppSpacing.md),
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
              ),
            ],
          ),
        ),
        LessonActionButton(
          label: 'فهمت!',
          icon: Icons.thumb_up_alt_rounded,
          onPressed: widget.api.completeScene,
        ),
      ],
    );
  }
}

/// تركيب واضح للألف المهموزة؛ عرضها كنص واحد كان يجعل الهمزة تدخل
/// خلف بطاقة عنوان المشهد في الشاشات الأفقية القصيرة.
class _LessonLetterGlyph extends StatelessWidget {
  const _LessonLetterGlyph({
    required this.letter,
    required this.compact,
    required this.glow,
  });

  final String letter;
  final bool compact;
  final double glow;

  TextStyle _style(double size) => AppTypography.letterHero.copyWith(
        fontSize: size,
        height: 1,
        shadows: [
          Shadow(
            color: AppColors.highlight.withValues(alpha: .6),
            blurRadius: glow * 40,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (!letter.startsWith('أ')) {
      return Text(letter, style: _style(compact ? 116 : 156));
    }
    return SizedBox(
      width: compact ? 90 : 120,
      height: compact ? 130 : 170,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
              top: compact ? 0 : 2,
              child: Text('ء', style: _style(compact ? 46 : 60))),
          Positioned(
              top: compact ? 50 : 64,
              child: Text('ا', style: _style(compact ? 102 : 136))),
        ],
      ),
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
      maxLines: 1,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
    );
  }
}

