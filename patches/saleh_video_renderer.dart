import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../lesson/widgets/saleh_character.dart' show SalehPose;
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
  static const _transitionDuration = Duration(milliseconds: 260);

  VideoPlayerController? _player;
  final Set<VideoPlayerController> _retiringPlayers = {};
  late SalehVideoClip _clip = SalehVideoClips.forPose(widget.pose);
  int _loadGeneration = 0;
  bool _completedReported = false;
  String? _error;

  bool get _shouldUsePoster =>
      widget.posterOnly || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (!_shouldUsePoster) unawaited(_load(widget.pose));
  }

  @override
  void didUpdateWidget(SalehVideoRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_shouldUsePoster &&
        (oldWidget.pose != widget.pose || oldWidget.posterOnly)) {
      unawaited(_load(widget.pose));
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
    if (_shouldUsePoster) {
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

