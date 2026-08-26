import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_spacing.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/widgets/app_card.dart';
import '../../core/design/widgets/classroom_background.dart';
import '../../domain/models/lesson.dart';
import '../../domain/models/timeline_event.dart';
import '../character/video/saleh_video_renderer.dart';
import 'character/saleh_character_controller.dart';
import 'lesson_controller.dart';
import 'scene_registry.dart';
import 'widgets/saleh_character.dart' show SalehPose;
import 'widgets/saleh_script_player.dart';

/// الأنشطة التفاعلية تُكمل نفسها من داخل اللوحة فقط. إبقاء زر «التالي»
/// العام فعالًا هنا كان يسمح بتجاوز الكتابة الحرة قبل أن يكتب الطفل.
bool lessonSceneAllowsGlobalNext(SceneType type) => switch (type) {
      SceneType.pronunciation ||
      SceneType.guidedWriting ||
      SceneType.freeWriting ||
      SceneType.multipleChoice ||
      SceneType.assessment ||
      SceneType.success =>
        false,
      _ => true,
    };

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.lessonId, this.initialScene});

  final String lessonId;
  final int? initialScene;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  SceneChannel? _channel;
  StreamSubscription<TimelineEvent>? _salehEvents;
  String? _channelSceneId;
  bool _jumpedToInitial = false;
  late final SalehCharacterController _saleh;

  @override
  void initState() {
    super.initState();
    _saleh = SalehCharacterController(
      audioPlaying: ref.read(audioServiceProvider).playing,
    )..addListener(_onSalehChanged);
  }

  void _onSalehChanged() {
    if (mounted) setState(() {});
  }

  void _triggerSaleh(String action) {
    if (action == 'narratingStart' || action == 'narratingStop') {
      _saleh.setNarrating(action == 'narratingStart');
      return;
    }
    final pose = switch (action) {
      'pointing' || 'point' => SalehPose.pointing,
      'waving' || 'greeting' => SalehPose.waving,
      'happy' || 'encouraging' => SalehPose.encouraging,
      'celebrating' || 'celebrate' => SalehPose.celebrating,
      // Listening intentionally reuses the approved Idle clip.
      'idle' || 'listening' || 'surprised' => SalehPose.idle,
      _ => SalehPose.idle,
    };
    _saleh.setPose(pose);
  }

  SceneChannel _channelFor(Scene scene) {
    if (_channelSceneId != scene.id) {
      _salehEvents?.cancel();
      _channel?.dispose();
      _channel = SceneChannel();
      _channelSceneId = scene.id;
      _saleh.reset();
      _salehEvents = _channel!.events.listen(_onTimelineEvent);
      final entryPose = switch (scene.type) {
        SceneType.welcome => SalehPose.waving,
        SceneType.explanation => SalehPose.pointing,
        SceneType.success => SalehPose.waving,
        _ => SalehPose.idle,
      };
      // تبدأ الحركة الدلالية الصحيحة مع المشهد نفسه، ولا تعتمد على وصول
      // مؤقت متأخر من سطر الكلام كي تظهر الإشارة أو التحية.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _channelSceneId == scene.id) _saleh.setPose(entryPose);
      });
    }
    return _channel!;
  }

  void _onTimelineEvent(TimelineEvent event) {
    switch (event.action) {
      case TimelineAction.salehPointAt:
        _triggerSaleh('pointing');
        break;
      case TimelineAction.salehCelebrate:
        _triggerSaleh('celebrating');
        break;
      case TimelineAction.playAnimation:
        _triggerSaleh(event.params['name'] == 'wave' ? 'greeting' : 'idle');
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _salehEvents?.cancel();
    _channel?.dispose();
    _saleh
      ..removeListener(_onSalehChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(childProfileProvider);
    final stateAsync = ref.watch(lessonControllerProvider(widget.lessonId));
    final controller = ref.read(
      lessonControllerProvider(widget.lessonId).notifier,
    );

    return Scaffold(
      body: ClassroomBackground(
        child: SafeArea(
          child: stateAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('تعذر تحميل الدرس\n$error')),
            data: (state) {
              final profile = profileAsync.valueOrNull;
              if (profile == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!_jumpedToInitial) {
                _jumpedToInitial = true;
                final target = widget.initialScene;
                if (target != null && target != state.sceneIndex) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => controller.jumpToScene(target),
                  );
                }
              }

              final scene = state.currentScene;
              final channel = _channelFor(scene);
              final api = SceneApi(
                profile: profile,
                channel: channel,
                completeScene: controller.completeScene,
                recordAttempt: controller.recordAttempt,
                recordAnswer: ({required bool correct}) =>
                    controller.recordAnswer(correct: correct),
                triggerSaleh: _triggerSaleh,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 1100 ||
                      constraints.maxHeight < 760) {
                    return _CompactLesson(
                      state: state,
                      scene: scene,
                      api: api,
                      onExit: () => context.go('/'),
                      salehPose: _saleh.pose,
                      onSalehCompleted: _saleh.notifyPoseCompleted,
                    );
                  }
                  return _DesktopLesson(
                    state: state,
                    scene: scene,
                    api: api,
                    onExit: () => context.go('/'),
                    onSkip: scene.canSkip
                        ? () => controller.completeScene(skipped: true)
                        : null,
                    salehPose: _saleh.pose,
                    onSalehCompleted: _saleh.notifyPoseCompleted,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopLesson extends StatelessWidget {
  const _DesktopLesson({
    required this.state,
    required this.scene,
    required this.api,
    required this.onExit,
    required this.onSkip,
    required this.salehPose,
    required this.onSalehCompleted,
  });

  final LessonRunState state;
  final Scene scene;
  final SceneApi api;
  final VoidCallback onExit;
  final VoidCallback? onSkip;
  final SalehPose salehPose;
  final ValueChanged<SalehPose> onSalehCompleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
          child: _TopBar(state: state, api: api, onExit: onExit),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 265),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _LessonBoard(
                          title: scene.title ?? state.lesson.title,
                          child: SceneRegistry.build(scene, api),
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 175,
                        child: _StepsRail(
                          scenes: state.lesson.scenes,
                          currentIndex: state.sceneIndex,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: 265,
                  child: IgnorePointer(
                    child: SalehVideoRenderer(
                      pose: salehPose,
                      width: 265,
                      height: 430,
                      onCompleted: onSalehCompleted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _HiddenScriptPlayer(
          scene: scene,
          api: api,
        ),
        SizedBox(
          height: 70,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                const SizedBox(width: 22),
                if (onSkip != null)
                  _PillButton(
                    label: 'تخطي',
                    icon: Icons.fast_forward_rounded,
                    onPressed: onSkip!,
                  )
                else
                  const SizedBox(width: 90),
                const SizedBox(width: 160),
                const Expanded(child: _BottomNavigation()),
                const SizedBox(width: 185),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactLesson extends StatelessWidget {
  const _CompactLesson({
    required this.state,
    required this.scene,
    required this.api,
    required this.onExit,
    required this.salehPose,
    required this.onSalehCompleted,
  });

  final LessonRunState state;
  final Scene scene;
  final SceneApi api;
  final VoidCallback onExit;
  final SalehPose salehPose;
  final ValueChanged<SalehPose> onSalehCompleted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final veryShort = constraints.maxHeight < 430;
      final gap = veryShort ? 6.0 : AppSpacing.sm;
      final headerHeight = veryShort ? 52.0 : 68.0;
      final characterWidth = (constraints.maxWidth * .20).clamp(112.0, 190.0);
      final stepsWidth = (constraints.maxWidth * .15).clamp(104.0, 145.0);
      return Padding(
        padding: EdgeInsets.fromLTRB(gap, gap, gap, 4),
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: _CompactTopBar(state: state, api: api, onExit: onExit),
            ),
            SizedBox(height: gap),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: characterWidth),
                        SizedBox(width: gap),
                        Expanded(
                          child: _LessonBoard(
                            title: scene.title ?? state.lesson.title,
                            compact: veryShort,
                            child: SceneRegistry.build(scene, api),
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          width: stepsWidth,
                          child: Center(
                            child: SizedBox(
                              width: stepsWidth,
                              child: _StepsRail(
                                scenes: state.lesson.scenes,
                                currentIndex: state.sceneIndex,
                                compact: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    // يعود جسم صالح إلى حجمه القديم. تمتد مساحة الرسم قليلًا
                    // نحو السبورة كي تظهر اليد فوقها، من دون تكبير الشخصية.
                    width: characterWidth * 1.35,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        (constraints.maxHeight - headerHeight) * .075,
                      ),
                      child: IgnorePointer(
                        // طبقة الفيديو للعرض فقط؛ المساحة الشفافة لا يجوز أن
                        // تعترض ضغط أزرار السبورة الواقعة خلف اليد.
                        child: SalehVideoRenderer(
                          pose: salehPose,
                          width: characterWidth * 1.35,
                          height: constraints.maxHeight - headerHeight - gap,
                          onCompleted: onSalehCompleted,
                        ),
                      ),
                    ),
                  ),
                  _HiddenScriptPlayer(
                    scene: scene,
                    api: api,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({
    required this.state,
    required this.api,
    required this.onExit,
  });

  final LessonRunState state;
  final SceneApi api;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          _GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Row(children: [
              Image.asset(
                'assets/character/saleh_video/saleh_idle_alpha_poster.png',
                width: 34,
                height: 44,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 5),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('أهلًا بك', style: TextStyle(fontSize: 10)),
                  Text(api.profile.name,
                      style: AppTypography.subtitle.copyWith(fontSize: 15)),
                ],
              ),
            ]),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            height: 48,
            child: _CircleButton(icon: Icons.home_rounded, onPressed: onExit),
          ),
          const SizedBox(width: 6),
          const Spacer(),
          SizedBox(
            width: 220,
            child: _GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: _LessonStepIndicator(
                title: state.lesson.title,
                compact: true,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 6),
          const _GlassCard(
            padding: EdgeInsets.symmetric(horizontal: 9, vertical: 12),
            child: Row(children: [
              Icon(Icons.star_rounded, color: Color(0xFFFFB623), size: 22),
              SizedBox(width: 3),
              Text('235', style: TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.api, required this.onExit});

  final LessonRunState state;
  final SceneApi api;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          _GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/character/saleh_video/saleh_idle_alpha_poster.png',
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.face_rounded),
                  ),
                ),
                const SizedBox(width: 9),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('أهلًا بك', style: AppTypography.caption),
                    Text(api.profile.name, style: AppTypography.subtitle),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _CircleButton(icon: Icons.home_rounded, onPressed: onExit),
          const Spacer(),
          SizedBox(
            width: 220,
            child: _GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: _LessonStepIndicator(
                title: state.lesson.title,
              ),
            ),
          ),
          const Spacer(),
          const _GlassCard(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: Color(0xFFFFB623), size: 28),
                SizedBox(width: 7),
                Text('235', style: AppTypography.subtitle),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _CircleButton(icon: Icons.menu_rounded, onPressed: () {}),
        ],
      ),
    );
  }
}

class _LessonStepIndicator extends StatelessWidget {
  const _LessonStepIndicator({
    required this.title,
    this.compact = false,
  });

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.subtitle.copyWith(fontSize: compact ? 16 : null),
        ),
      ),
    );
  }
}

class _LessonBoard extends StatelessWidget {
  const _LessonBoard(
      {required this.title, required this.child, this.compact = false});

  final String title;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4EA7A3),
        borderRadius: BorderRadius.circular(compact ? 28 : 42),
        border: Border.all(color: const Color(0xFF2F817F), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D684C37),
            offset: Offset(0, 12),
            blurRadius: 24,
          ),
        ],
      ),
      padding: EdgeInsets.all(compact ? 7 : 13),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E8), Color(0xFFFFE8BF)],
          ),
          borderRadius: BorderRadius.circular(compact ? 21 : 30),
          boxShadow: const [
            BoxShadow(color: Color(0x305A432F), blurRadius: 7, spreadRadius: 1),
          ],
        ),
        padding: EdgeInsets.fromLTRB(12, compact ? 30 : 42, 12, 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: compact ? -23 : -29,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: compact ? 4 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EA),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadow, blurRadius: 10),
                    ],
                  ),
                  child: Text(title,
                      style: AppTypography.subtitle.copyWith(
                        fontSize: compact ? 15 : null,
                      )),
                ),
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

/// يبقي التعليق الصوتي وأحداث التزامن فعّالة من دون شغل مساحة مرئية.
/// أزيل شريط النص السفلي بناءً على التصميم المعتمد، لكن المشغّل يظل مركّبًا
/// حتى لا تتوقف أصوات الترحيب والشرح أو حركات صالح المرتبطة بها.
class _HiddenScriptPlayer extends StatelessWidget {
  const _HiddenScriptPlayer({
    required this.scene,
    required this.api,
    this.compact = false,
  });

  final Scene scene;
  final SceneApi api;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: compact ? 420 : 640,
        child: SalehScriptPlayer(
          key: ValueKey('script_${scene.id}'),
          lines: scene.lines,
          profile: api.profile,
          tailDirection: SpeechTailDirection.start,
          compact: compact,
          onNarratingChanged: (narrating) => api.triggerSaleh(
            narrating ? 'narratingStart' : 'narratingStop',
          ),
          onEvent: api.channel.emit,
          onFinished: api.channel.markFinished,
        ),
      ),
    );
  }
}

class _StepsRail extends StatelessWidget {
  const _StepsRail({
    required this.scenes,
    required this.currentIndex,
    this.compact = false,
  });

  final List<Scene> scenes;
  final int currentIndex;
  final bool compact;

  static const icons = [
    Icons.waving_hand_rounded,
    Icons.menu_book_rounded,
    Icons.music_note_rounded,
    Icons.chat_bubble_rounded,
    Icons.mic_rounded,
    Icons.edit_rounded,
    Icons.draw_rounded,
    Icons.fact_check_rounded,
    Icons.emoji_events_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 10,
        vertical: compact ? 6 : 12,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        primary: false,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: scenes.length,
        separatorBuilder: (_, __) => SizedBox(height: compact ? 2 : 5),
        itemBuilder: (context, index) {
          final current = index == currentIndex;
          final done = index < currentIndex;
          return AnimatedContainer(
            duration: AppDurations.normal,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 9,
              vertical: compact ? 3 : 8,
            ),
            decoration: BoxDecoration(
              color: current ? const Color(0xFFFFF2D6) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    current ? const Color(0xFFF2B238) : const Color(0x1F6B4E3D),
                width: current ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icons[index.clamp(0, icons.length - 1)],
                  size: compact ? 14 : 20,
                  color: done ? AppColors.success : AppColors.brandBrown,
                ),
                SizedBox(width: compact ? 3 : 7),
                Expanded(
                  child: Text(
                    scenes[index].title ?? '',
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.fade,
                    style: AppTypography.caption.copyWith(
                      fontSize: compact ? 9 : null,
                      height: compact ? 1.05 : null,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  done ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: compact ? 11 : 17,
                  color: done ? AppColors.success : const Color(0xFFD8CDBE),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  static const items = [
    (Icons.home_rounded, 'الرئيسية'),
    (Icons.school_rounded, 'الاختبارات'),
    (Icons.handshake_rounded, 'المبادرات'),
    (Icons.chat_bubble_rounded, 'الكلمات'),
    (Icons.photo_rounded, 'المشاركات'),
    (Icons.emoji_events_rounded, 'لوحة الشرف'),
    (Icons.workspace_premium_rounded, 'إنجازاتي'),
  ];

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final item in items)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.$1, size: 24, color: AppColors.brandBrown),
                  Text(
                    item.$2,
                    maxLines: 1,
                    style: AppTypography.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBF4), Color(0xFFF7E8D5)],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFFFF8EA), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2D71523B),
            offset: Offset(0, 5),
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: EdgeInsets.zero,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.brandBrown),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: EdgeInsets.zero,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
