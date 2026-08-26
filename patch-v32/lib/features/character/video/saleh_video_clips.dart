import '../../lesson/widgets/saleh_character.dart' show SalehPose;

class SalehVideoClip {
  const SalehVideoClip({
    required this.asset,
    required this.iosAnimatedAsset,
    required this.poster,
    required this.loop,
    required this.duration,
  });

  final String asset;
  final String iosAnimatedAsset;
  final String poster;
  final bool loop;
  final Duration duration;
}

/// سجل المقاطع المعتمدة فقط. حالة الاستماع لا تحتاج ملفًا مستقلًا؛
/// يظل المحرك على [SalehPose.idle].
abstract final class SalehVideoClips {
  static const idle = SalehVideoClip(
    asset: 'assets/character/saleh_video/saleh_idle_alpha.webm',
    iosAnimatedAsset: 'assets/character/saleh_video/saleh_idle_alpha.webp',
    poster: 'assets/character/saleh_video/saleh_idle_alpha_poster.png',
    loop: true,
    duration: Duration(milliseconds: 5040),
  );
  static const talking = SalehVideoClip(
    asset: 'assets/character/saleh_video/saleh_talking_alpha.webm',
    iosAnimatedAsset: 'assets/character/saleh_video/saleh_talking_alpha.webp',
    poster: 'assets/character/saleh_video/saleh_talking_alpha_poster.png',
    loop: true,
    duration: Duration(milliseconds: 5040),
  );
  static const pointing = SalehVideoClip(
    asset: 'assets/character/saleh_video/saleh_pointing_right_alpha.webm',
    iosAnimatedAsset:
        'assets/character/saleh_video/saleh_pointing_right_alpha.webp',
    poster:
        'assets/character/saleh_video/saleh_pointing_right_alpha_poster.png',
    loop: true,
    duration: Duration(milliseconds: 5040),
  );
  static const greeting = SalehVideoClip(
    asset: 'assets/character/saleh_video/saleh_greeting_alpha.webm',
    iosAnimatedAsset: 'assets/character/saleh_video/saleh_greeting_alpha.webp',
    poster: 'assets/character/saleh_video/saleh_greeting_alpha_poster.png',
    loop: true,
    duration: Duration(milliseconds: 5040),
  );
  static const encouraging = SalehVideoClip(
    asset: 'assets/character/saleh_video/saleh_encouraging_alpha.webm',
    iosAnimatedAsset:
        'assets/character/saleh_video/saleh_encouraging_alpha.webp',
    poster: 'assets/character/saleh_video/saleh_encouraging_alpha_poster.png',
    loop: true,
    duration: Duration(milliseconds: 7040),
  );
  static const celebrating = SalehVideoClip(
    asset: 'assets/character/saleh_video/saleh_celebrating_alpha.webm',
    iosAnimatedAsset:
        'assets/character/saleh_video/saleh_celebrating_alpha.webp',
    poster: 'assets/character/saleh_video/saleh_celebrating_alpha_poster.png',
    loop: true,
    duration: Duration(milliseconds: 7040),
  );

  static SalehVideoClip forPose(SalehPose pose) => switch (pose) {
        SalehPose.idle => idle,
        SalehPose.talking => talking,
        SalehPose.pointing => pointing,
        // وضع التفكير يستخدم حركة التنفس الهادئة نفسها، ويضيف العارض
        // الفقاعة الدلالية فوق صالح من دون إدخال أصل شخصية مختلف.
        SalehPose.thinking => idle,
        SalehPose.waving => greeting,
        SalehPose.encouraging => encouraging,
        SalehPose.celebrating => celebrating,
      };
}
