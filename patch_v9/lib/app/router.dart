import 'package:go_router/go_router.dart';

import '../features/character/video/saleh_video_dev_screen.dart';
import '../features/home/home_screen.dart';
import '../features/lesson/lesson_screen.dart';

/// مسارات التطبيق. المسارات معلنة ومعرّفة بالمعرفات (وليس بالمحتوى)،
/// فأي درس جديد من لوحة المحتوى يعمل بنفس المسار /lesson/:id.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/program/:programId',
      builder: (context, state) => ProgramScreen(
        programId: state.pathParameters['programId']!,
      ),
    ),
    GoRoute(
      path: '/program/:programId/stage/:stageId',
      builder: (context, state) => StageScreen(
        programId: state.pathParameters['programId']!,
        stageId: state.pathParameters['stageId']!,
      ),
    ),
    GoRoute(
      path: '/program/:programId/stage/:stageId/level/:levelId',
      builder: (context, state) => LevelScreen(
        programId: state.pathParameters['programId']!,
        stageId: state.pathParameters['stageId']!,
        levelId: state.pathParameters['levelId']!,
      ),
    ),
    GoRoute(
      path: '/saleh/video',
      builder: (context, state) => const SalehVideoDevScreen(),
    ),
    GoRoute(
      path: '/lesson/:id',
      builder: (context, state) => LessonScreen(
        lessonId: state.pathParameters['id']!,
        // معاينة مشهد محدد مباشرة: /lesson/tha?scene=3
        initialScene: int.tryParse(state.uri.queryParameters['scene'] ?? ''),
      ),
    ),
  ],
);
