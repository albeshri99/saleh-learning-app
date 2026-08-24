import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/widgets/app_card.dart';
import '../../core/design/widgets/classroom_background.dart';
import '../../domain/models/child_profile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _programs = <_ProgramTileData>[
    _ProgramTileData('تأسيس اللغة العربية', 'أ ب ت', Icons.menu_book_rounded,
        AppColors.brandGreen, true),
    _ProgramTileData('ألعاب تعليمية', 'ألعب وأتعلّم', Icons.extension_rounded,
        AppColors.brandOrange, false),
    _ProgramTileData('حفظ قصار السور', 'قرآن كريم', Icons.auto_stories_rounded,
        AppColors.brandPeriwinkle, false),
    _ProgramTileData('حفظ المتون', 'حفظ وفهم', Icons.school_rounded,
        AppColors.brandViolet, false),
    _ProgramTileData('أناشيد', 'استمع وردّد', Icons.music_note_rounded,
        AppColors.brandYellow, false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(childProfileProvider).valueOrNull;
    return _CatalogShell(
      title: 'برامج نتعلّم مع صالح',
      profile: profile,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _programs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _ProgramCard(
                      data: _programs[i],
                      onTap: _programs[i].enabled
                          ? () => context.go('/program/arabic_foundation')
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () async {
                final progress = await ref
                    .read(progressRepositoryProvider)
                    .loadLessonProgress('tha');
                if (!context.mounted) return;
                context
                    .go('/lesson/tha?scene=${progress?.lastSceneIndex ?? 0}');
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('استمر من حيث توقفت'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                textStyle: AppTypography.button.copyWith(fontSize: 18),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key, required this.programId});
  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(programsProvider);
    return programs.when(
      loading: () => const _LoadingCatalog(),
      error: (error, _) => _ErrorCatalog(error: error),
      data: (items) {
        final program = items.where((p) => p.id == programId).firstOrNull;
        if (program == null) {
          return const _ErrorCatalog(error: 'البرنامج غير موجود');
        }
        return _CatalogShell(
          title: program.title,
          onBack: () => context.go('/'),
          child: Row(
            children: [
              for (var i = 0; i < program.stages.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(
                  child: _NavigationCard(
                    icon: Icons.route_rounded,
                    title: program.stages[i].title,
                    subtitle: 'مرحلة التعلم ${i + 1}',
                    progressLabel: i == 0 ? 'تابع من هنا' : 'لم تبدأ',
                    onTap: () => context.go(
                      '/program/$programId/stage/${program.stages[i].id}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class StageScreen extends ConsumerWidget {
  const StageScreen(
      {super.key, required this.programId, required this.stageId});
  final String programId;
  final String stageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(programsProvider);
    return programs.when(
      loading: () => const _LoadingCatalog(),
      error: (error, _) => _ErrorCatalog(error: error),
      data: (items) {
        final program = items.where((p) => p.id == programId).firstOrNull;
        final stage = program?.stages.where((s) => s.id == stageId).firstOrNull;
        if (stage == null) {
          return const _ErrorCatalog(error: 'المرحلة غير موجودة');
        }
        return _CatalogShell(
          title: stage.title,
          onBack: () => context.go('/program/$programId'),
          child: Row(
            children: [
              for (var i = 0; i < stage.levels.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(
                  child: _NavigationCard(
                    icon: Icons.stairs_rounded,
                    title: stage.levels[i].title,
                    subtitle: '${stage.levels[i].lessons.length} درس',
                    progressLabel: i == 0 ? 'قيد التعلّم' : 'لم تبدأ',
                    onTap: () => context.go(
                      '/program/$programId/stage/$stageId/level/${stage.levels[i].id}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class LevelScreen extends ConsumerWidget {
  const LevelScreen({
    super.key,
    required this.programId,
    required this.stageId,
    required this.levelId,
  });
  final String programId;
  final String stageId;
  final String levelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(programsProvider);
    return programs.when(
      loading: () => const _LoadingCatalog(),
      error: (error, _) => _ErrorCatalog(error: error),
      data: (items) {
        final program = items.where((p) => p.id == programId).firstOrNull;
        final stage = program?.stages.where((s) => s.id == stageId).firstOrNull;
        final level = stage?.levels.where((l) => l.id == levelId).firstOrNull;
        if (level == null) {
          return const _ErrorCatalog(error: 'المجموعة غير موجودة');
        }
        return _CatalogShell(
          title: level.title,
          onBack: () => context.go('/program/$programId/stage/$stageId'),
          child: Row(
            children: [
              for (var i = 0; i < level.lessons.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: _NavigationCard(
                    icon: Icons.play_circle_fill_rounded,
                    title:
                        '${level.lessons[i].emoji ?? '📖'}  ${level.lessons[i].title}',
                    subtitle: level.lessons[i].subtitle ?? '',
                    progressLabel: 'ابدأ الدرس',
                    onTap: () =>
                        context.go('/lesson/${level.lessons[i].lessonId}'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CatalogShell extends StatelessWidget {
  const _CatalogShell({
    required this.title,
    required this.child,
    this.profile,
    this.onBack,
  });
  final String title;
  final Widget child;
  final ChildProfile? profile;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ClassroomBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: Column(
              children: [
                SizedBox(
                  height: 62,
                  child: Row(
                    children: [
                      if (onBack != null)
                        IconButton.filled(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface),
                        )
                      else
                        const CircleAvatar(
                          radius: 23,
                          backgroundColor: AppColors.surface,
                          child: Text('ص',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          child: Center(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.title.copyWith(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 132,
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          child: Text(
                            profile == null
                                ? 'مرحبًا بك'
                                : 'أهلًا ${profile!.name}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTypography.subtitle.copyWith(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                    child: AppCard(
                        padding: const EdgeInsets.all(16), child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgramTileData {
  const _ProgramTileData(
      this.title, this.subtitle, this.icon, this.color, this.enabled);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.data, this.onTap});
  final _ProgramTileData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: data.color.withValues(alpha: data.enabled ? .16 : .08),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.enabled ? data.icon : Icons.lock_rounded,
                  size: 42,
                  color: data.enabled ? data.color : AppColors.inkSoft),
              const SizedBox(height: 8),
              Text(data.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle
                      .copyWith(fontSize: 17, height: 1.2)),
              const SizedBox(height: 4),
              Text(data.enabled ? data.subtitle : 'قريبًا',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progressLabel,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String progressLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandCream,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LinearProgressIndicator(
                value: .12,
                minHeight: 7,
                color: AppColors.success,
                backgroundColor: AppColors.letterGuide,
              ),
              const SizedBox(height: 16),
              Icon(icon, color: AppColors.primary, size: 48),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title),
              Text(subtitle, style: AppTypography.caption),
              const SizedBox(height: 10),
              Text(progressLabel,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.success,
                    fontSize: 15,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCatalog extends StatelessWidget {
  const _LoadingCatalog();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: ClassroomBackground(
            child: Center(child: CircularProgressIndicator())),
      );
}

class _ErrorCatalog extends StatelessWidget {
  const _ErrorCatalog({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: ClassroomBackground(
            child: Center(child: Text('تعذر تحميل المحتوى\n$error'))),
      );
}
