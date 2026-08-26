import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import 'letter_strokes.dart';

/// «شاهد كيف نكتب»: يظهر الحرف باهتًا ثم يُرسم مساره تدريجيًا بلون مختلف.
class WatchLetterAnimation extends StatefulWidget {
  const WatchLetterAnimation({
    super.key,
    required this.strokes,
    this.autoPlay = true,
    this.duration = const Duration(milliseconds: 3200),
    this.onFinished,
  });

  final List<StrokeSpec> strokes;
  final bool autoPlay;
  final Duration duration;
  final VoidCallback? onFinished;

  @override
  State<WatchLetterAnimation> createState() => _WatchLetterAnimationState();
}

class _WatchLetterAnimationState extends State<WatchLetterAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished?.call();
    });
    if (widget.autoPlay) play();
  }

  void play() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _StrokesPainter(
          strokes: widget.strokes,
          progress: _c.value,
          completedColor: AppColors.letterTraced,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// التتبع الموجه: دليل باهت + نقطة بداية خضراء، والطفل يمرر إصبعه
/// على المسار فيتلون خلفه. الضربات النقطية (النقاط الثلاث) تُنقر نقرًا.
class GuidedTracingCanvas extends StatefulWidget {
  const GuidedTracingCanvas({
    super.key,
    required this.letter,
    required this.strokes,
    required this.onStrokeCompleted,
    required this.onAllCompleted,
  });

  final String letter;
  final List<StrokeSpec> strokes;
  final void Function(int strokeIndex) onStrokeCompleted;
  final VoidCallback onAllCompleted;

  @override
  State<GuidedTracingCanvas> createState() => _GuidedTracingCanvasState();
}

class _GuidedTracingCanvasState extends State<GuidedTracingCanvas> {
  int _strokeIndex = 0;
  int _sampleIndex = 0;
  List<Offset> _samples = const [];
  Size _size = Size.zero;

  // العينات كثيفة، لكن لا يجوز لحركة واحدة أن تقفز عبر جزء كبير من الحرف.
  // السماحية نسبية للمساحة كي يبقى السلوك واحدًا على مقاسات iPhone المختلفة.
  double get _tolerance => (_size.shortestSide * .075).clamp(18.0, 30.0);
  static const _sampleCount = 96;
  static const _maxLookAhead = 5;

  bool get _done => _strokeIndex >= widget.strokes.length;

  void _prepare(Size size) {
    if (_size == size && _samples.isNotEmpty) return;
    _size = size;
    _samples = _done
        ? const []
        : widget.strokes[_strokeIndex].samples(size, count: _sampleCount);
  }

  void _advanceStroke() {
    widget.onStrokeCompleted(_strokeIndex);
    setState(() {
      _strokeIndex++;
      _sampleIndex = 0;
      _samples = _done
          ? const []
          : widget.strokes[_strokeIndex].samples(_size, count: _sampleCount);
    });
    if (_done) widget.onAllCompleted();
  }

  void _handleTouch(Offset pos) {
    if (_done) return;
    final stroke = widget.strokes[_strokeIndex];
    if (stroke.kind == StrokeKind.dot) return; // النقاط بالنقر لا بالسحب
    if (_samples.isEmpty) return;

    // يجب بدء كل ضربة من نقطتها الأولى، ثم يسمح كل حدث لمس بتقدم صغير فقط.
    // البحث المحدود يعوض سرعة الإصبع الطبيعية، لكنه يمنع القفز إلى نهاية
    // الألف أو الانتقال إلى الهمزة/الجسم بترتيب خاطئ.
    final lastCandidate = math.min(
      _sampleIndex + _maxLookAhead,
      _samples.length - 1,
    );
    var matched = -1;
    for (var i = _sampleIndex; i <= lastCandidate; i++) {
      if ((pos - _samples[i]).distance <= _tolerance) matched = i;
    }
    if (matched < 0) return;
    _sampleIndex = matched + 1;
    if (_sampleIndex >= _samples.length) {
      _advanceStroke();
    } else {
      setState(() {});
    }
  }

  void _handleTap(Offset pos) {
    if (_done) return;
    final stroke = widget.strokes[_strokeIndex];
    if (stroke.kind != StrokeKind.dot) return;
    final c = stroke.samples(_size).first;
    if ((pos - c).distance < _tolerance) _advanceStroke();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _prepare(Size(constraints.maxWidth, constraints.maxHeight));
        final progress = _done
            ? 1.0
            : _samples.isEmpty
                ? 0.0
                : _sampleIndex / _samples.length;
        return GestureDetector(
          onPanDown: (d) => _handleTouch(d.localPosition),
          onPanUpdate: (d) => _handleTouch(d.localPosition),
          onTapDown: (d) => _handleTap(d.localPosition),
          child: CustomPaint(
            painter: _StrokesPainter(
              letter: widget.letter,
              strokes: widget.strokes,
              completedStrokes: _strokeIndex,
              activeStrokeProgress: progress,
              completedColor: AppColors.letterTraced,
              showStartDot: !_done,
              startDot: _done
                  ? null
                  : (_samples.isEmpty
                      ? null
                      : _samples[_sampleIndex.clamp(0, _samples.length - 1)]),
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

/// الكتابة الحرة: حبر حر بلا دليل، مع مسح وإنهاء.
class FreeWritingCanvas extends StatefulWidget {
  const FreeWritingCanvas({super.key, this.onInkChanged});

  final ValueChanged<bool>? onInkChanged;

  @override
  State<FreeWritingCanvas> createState() => FreeWritingCanvasState();
}

class FreeWritingCanvasState extends State<FreeWritingCanvas> {
  final List<List<Offset>> _lines = [];

  bool get hasInk => _lines.any((l) => l.length > 2);

  void clear() {
    setState(_lines.clear);
    widget.onInkChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => setState(() => _lines.add([d.localPosition])),
      onPanUpdate: (d) {
        setState(() => _lines.last.add(d.localPosition));
        widget.onInkChanged?.call(hasInk);
      },
      child: CustomPaint(
        painter: _InkPainter(lines: _lines),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter({
    required this.strokes,
    this.letter = 'ث',
    this.progress,
    this.completedStrokes = 0,
    this.activeStrokeProgress = 0,
    required this.completedColor,
    this.showStartDot = false,
    this.startDot,
  });

  /// وضع «شاهد»: تقدم كلي 0..1 على كل الضربات. وإلا نستخدم
  /// [completedStrokes] + [activeStrokeProgress] (وضع التتبع).
  final double? progress;
  final String letter;
  final List<StrokeSpec> strokes;
  final int completedStrokes;
  final double activeStrokeProgress;
  final Color completedColor;
  final bool showStartDot;
  final Offset? startDot;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    final guideRadius = (size.shortestSide * .01).clamp(1.8, 3.8);
    final strokeWidth = (size.shortestSide * .035).clamp(8.0, 18.0);

    // الدليل نقاط كثيرة متقاربة تمثل المسار الحقيقي، لا قصًّا تدريجيًا
    // لصورة الحرف. لذلك يسير الإصبع فوق الهمزة كاملة ثم جسم الألف.
    for (final stroke in strokes) {
      // دليل نقطي كثيف يوضح مسار الخط الحقيقي من البداية إلى النهاية.
      for (final point in stroke.samples(size, count: 56)) {
        canvas.drawCircle(
          point,
          guideRadius * stroke.strokeScale,
          Paint()..color = AppColors.letterGuide.withValues(alpha: .78),
        );
      }
    }

    for (var i = 0; i < strokes.length; i++) {
      final double strokeProgress;
      if (progress != null) {
        strokeProgress = (progress! * strokes.length - i).clamp(0.0, 1.0);
      } else if (i < completedStrokes) {
        strokeProgress = 1;
      } else if (i == completedStrokes) {
        strokeProgress = activeStrokeProgress.clamp(0.0, 1.0);
      } else {
        strokeProgress = 0;
      }
      if (strokeProgress <= 0) continue;
      final stroke = strokes[i];
      final currentStrokeWidth = strokeWidth * stroke.strokeScale;
      final paint = Paint()
        ..color = completedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (stroke.kind == StrokeKind.dot) {
        final center = stroke.samples(size).first;
        canvas.drawCircle(
            center, currentStrokeWidth * .72, Paint()..color = completedColor);
        continue;
      }
      final path = stroke.scaledPath(size);
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * strokeProgress),
          paint,
        );
      }
    }

    // نقطة البداية الخضراء النابضة (ثابتة هنا؛ النبض من إعادة الرسم)
    if (showStartDot && startDot != null) {
      final activeStrokeIndex =
          completedStrokes.clamp(0, math.max(0, strokes.length - 1)).toInt();
      final startDotRadius =
          (size.shortestSide * 0.025 * strokes[activeStrokeIndex].strokeScale)
              .clamp(7.0, 14.0);
      canvas.drawCircle(
        startDot!,
        startDotRadius,
        Paint()..color = AppColors.success,
      );
      canvas.drawCircle(
        startDot!,
        startDotRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );

      // مؤشر اليد يرافق نقطة التقدم بدل أن يترك الطفل أمام خط جامد.
      final hand = TextPainter(
        text: const TextSpan(text: '☝️', style: TextStyle(fontSize: 24)),
        textDirection: TextDirection.ltr,
      )..layout();
      hand.paint(
        canvas,
        startDot! + Offset(-hand.width / 2, size.shortestSide * 0.055),
      );
    }
  }

  @override
  bool shouldRepaint(_StrokesPainter old) =>
      old.progress != progress ||
      old.completedStrokes != completedStrokes ||
      old.activeStrokeProgress != activeStrokeProgress ||
      old.startDot != startDot;
}

/// الحالة المكتملة تستخدم المسارات نفسها تمامًا التي شاهدها الطفل وتتبعها.
/// لا تُستبدل بمحرف خط مختلف كي لا يتغير شكل الألف أو حجمه بعد النجاح.
class CompletedTracingCanvas extends StatelessWidget {
  const CompletedTracingCanvas({
    super.key,
    required this.strokes,
  });

  final List<StrokeSpec> strokes;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StrokesPainter(
        strokes: strokes,
        progress: 1,
        completedColor: AppColors.letterTraced,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter({required this.lines});

  final List<List<Offset>> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.shortestSide * 0.05
      ..color = AppColors.letterPrimary;
    for (final line in lines) {
      if (line.length < 2) {
        if (line.isNotEmpty) {
          canvas.drawCircle(line.first, ink.strokeWidth / 2, ink);
        }
        continue;
      }
      final path = Path()..moveTo(line.first.dx, line.first.dy);
      for (final p in line.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => true;
}
