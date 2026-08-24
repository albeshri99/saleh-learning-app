import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../lesson/widgets/saleh_character.dart' show SalehPose;
import '../two_d/saleh_2d_idle.dart';
import 'saleh_video_clips.dart';

@immutable
class SalehVideoDiagnostics {
  const SalehVideoDiagnostics({
    required this.ready,
    required this.playing,
    required this.duration,
    required this.position,
    required this.error,
  });

  final bool ready;
  final bool playing;
  final Duration duration;
  final Duration position;
  final String? error;
}

/// يبقى المقطع الحالي ظاهرًا حتى يجهز المقطع التالي، فلا يظهر وميض أسود.
/// المقاطع غير المتكررة تبلغ [onCompleted] ليعيدها المتحكم إلى Idle.
class SalehVideoRenderer extends StatefulWidget {
  const SalehVideoRenderer({
    super.key,
    this.pose = SalehPose.idle,
    this.width,
    this.height,
    this.onCompleted,
    this.onDiagnostics,
    this.posterOnly = false,
  });

  final SalehPose pose;
  final double? width;
  final double? height;
  final ValueChanged<SalehPose>? onCompleted;
  final ValueChanged<SalehVideoDiagnostics>? onDiagnostics;

  /// Safari على iPhone لا يفك شفافية VP9/WebM بصورة موثوقة.
  /// في معاينة الهاتف نعرض الملصق الشفاف بدل مستطيل فيديو أسود.
  final bool posterOnly;

  @override
  State<SalehVideoRenderer> createState() => _SalehVideoRendererState();
}

class _SalehVideoRendererState extends State<SalehVideoRenderer> {
  static const _transitionDuration = Duration(milliseconds: 420);

  VideoPlayerController? _player;
  final Set<VideoPlayerController> _retiringPlayers = {};
  late SalehVideoClip _clip = SalehVideoClips.forPose(widget.pose);
  int _loadGeneration = 0;
  bool _completedReported = false;
  String? _error;
  Timer? _animationTimer;

  bool get _usesAnimatedAsset => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_usesAnimatedAsset) {
      _showAnimatedPose(widget.pose, notify: false);
    } else if (!widget.posterOnly) {
      unawaited(_load(widget.pose));
    }
  }

  @override
  void didUpdateWidget(SalehVideoRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_usesAnimatedAsset && oldWidget.pose != widget.pose) {
      _showAnimatedPose(widget.pose);
    } else if (!widget.posterOnly &&
        (oldWidget.pose != widget.pose || oldWidget.posterOnly)) {
      unawaited(_load(widget.pose));
    }
  }

  void _showAnimatedPose(SalehPose pose, {bool notify = true}) {
    _animationTimer?.cancel();
    final nextClip = SalehVideoClips.forPose(pose);
    if (notify && mounted) setState(() => _clip = nextClip);
    if (!nextClip.loop) {
      _animationTimer = Timer(nextClip.duration, () {
        if (mounted && widget.pose == pose) widget.onCompleted?.call(pose);
      });
    }
  }

  Future<void> _load(SalehPose pose) async {
    final generation = ++_loadGeneration;
    final nextClip = SalehVideoClips.forPose(pose);
    final next = VideoPlayerController.asset(nextClip.asset);
    try {
      await next.initialize();
      await next.setVolume(0);
      await next.setLooping(nextClip.loop);
      await next.seekTo(Duration.zero);
      await next.play();
      if (!mounted || generation != _loadGeneration) {
        await next.dispose();
        return;
      }
      final previous = _player;
      previous?.removeListener(_onPlayerChanged);
      next.addListener(_onPlayerChanged);
      setState(() {
        _player = next;
        _clip = nextClip;
        _completedReported = false;
        _error = null;
      });
      if (previous != null) unawaited(_retire(previous));
      _report();
    } catch (error) {
      await next.dispose();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = error.toString());
      _report();
    }
  }

  Future<void> _retire(VideoPlayerController player) async {
    _retiringPlayers.add(player);
    await Future<void>.delayed(_transitionDuration);
    if (_retiringPlayers.remove(player)) await player.dispose();
  }

  void _onPlayerChanged() {
    final player = _player;
    if (player == null || !mounted) return;
    final value = player.value;
    if (!_clip.loop &&
        !_completedReported &&
        value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 80)) {
      _completedReported = true;
      widget.onCompleted?.call(widget.pose);
    }
    _report();
  }

  void _report() {
    final callback = widget.onDiagnostics;
    final player = _player;
    if (callback == null) return;
    callback(
      SalehVideoDiagnostics(
        ready: player?.value.isInitialized ?? false,
        playing: player?.value.isPlaying ?? false,
        duration: player?.value.duration ?? Duration.zero,
        position: player?.value.position ?? Duration.zero,
        error: _error ?? player?.value.errorDescription,
      ),
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    _animationTimer?.cancel();
    _player?.removeListener(_onPlayerChanged);
    final player = _player;
    if (player != null) unawaited(player.dispose());
    for (final retiring in _retiringPlayers) {
      unawaited(retiring.dispose());
    }
    _retiringPlayers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pose == SalehPose.idle) {
      return Saleh2DIdle(width: widget.width, height: widget.height);
    }
    if (_usesAnimatedAsset) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheWidth = (((widget.width ?? 260) * dpr).round())
          .clamp(360, 720);
      final animatedImage = Image.asset(
        _clip.iosAnimatedAsset,
        key: ValueKey(_clip.iosAnimatedAsset),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheWidth,
      );
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedSwitcher(
          duration: _transitionDuration,
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          child: widget.pose == SalehPose.encouraging
              ? ColorFiltered(
                  key: const ValueKey('encouraging_despill'),
                  colorFilter: const ColorFilter.matrix([
                    1, 0, 0, 0, 0,
                    0, 1, 0, 0, 0,
                    0, 0, 1, 0, 0,
                    .9, -1.4, .9, 1, 0,
                  ]),
                  child: animatedImage,
                )
              : animatedImage,
        ),
      );
    }
    if (widget.posterOnly) {
      final poster = SalehVideoClips.forPose(widget.pose).poster;
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.asset(
          poster,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
        ),
      );
    }
    final player = _player;
    final ready = player?.value.isInitialized ?? false;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedSwitcher(
        duration: _transitionDuration,
        reverseDuration: _transitionDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild
          ],
        ),
        child: ready
            ? FittedBox(
                key: ValueKey(_clip.asset),
                fit: BoxFit.contain,
                child: SizedBox(
                  width: player!.value.size.width,
                  height: player.value.size.height,
                  child: VideoPlayer(player),
                ),
              )
            : Image.asset(
                _clip.poster,
                key: ValueKey(_clip.poster),
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
      ),
    );
  }
}

