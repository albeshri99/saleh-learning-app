import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import 'letter_strokes.dart';

/// «شاهد كيف نكتب»: يظهر الحرف باهتًا ثم يُرسم مساره تدريجيًا بلون مختلف.
class WatchLetterAnimation extends StatefulWidget {
  const WatchLetterAnimation({
    super.key,
    required this.letter,
    required this.strokes,
    this.autoPlay = true,
    this.duration = const Duration(milliseconds: 3200),
    this.onFinished,
  });

  final String letter;
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
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          _LetterGuideBackdrop(letter: widget.letter),
          CustomPaint(
            painter: _StrokesPainter(
              letter: widget.letter,
              strokes: widget.strokes,
              progress: _c.value,
              completedColor: AppColors.letterTraced,
            ),
            child: const SizedBox.expand(),
          ),
        ],
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              _LetterGuideBackdrop(letter: widget.letter),
              CustomPaint(
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
                          : _samples[
                              _sampleIndex.clamp(0, _samples.length - 1)]),
                ),
                child: const SizedBox.expand(),
              ),
            ],
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
    final isAlif = letter.startsWith('أ');
    final strokeWidth = (size.shortestSide * .035).clamp(8.0, 18.0);

    double progressFor(int index) {
      if (progress != null) {
        return (progress! * strokes.length - index).clamp(0.0, 1.0);
      }
      if (index < completedStrokes) return 1;
      if (index == completedStrokes) {
        return activeStrokeProgress.clamp(0.0, 1.0);
      }
      return 0;
    }

    // الدليل نقاط كثيرة متقاربة تمثل المسار الحقيقي، لا قصًّا تدريجيًا
    // لصورة الحرف. لذلك يسير الإصبع فوق الفتحة ثم الهمزة ثم جسم الألف.
    for (var i = 0; i < strokes.length; i++) {
      if (isAlif) break;
      final stroke = strokes[i];
      // دليل نقطي كثيف يوضح مسار الخط الحقيقي من البداية إلى النهاية.
      for (final point in stroke.samples(size, count: 56)) {
        canvas.drawCircle(
          point,
          guideRadius * stroke.strokeScale,
          Paint()..color = AppColors.letterGuide.withValues(alpha: .78),
        );
      }
    }

    if (isAlif) {
      final parts = _AlifGuideGeometry.parts(size);
      for (var i = 0; i < math.min(parts.length, strokes.length); i++) {
        final partProgress = progressFor(i);
        if (partProgress <= 0) continue;
        final path = parts[i];
        final bounds = path.getBounds();
        canvas.save();
        canvas.clipPath(path, doAntiAlias: true);
        // تعبئة رأسية حقيقية داخل حدود الجزء: الفتحة، ثم الهمزة، ثم الجسم.
        canvas.drawRect(
          Rect.fromLTRB(
            bounds.left - 2,
            bounds.top - 2,
            bounds.right + 2,
            bounds.top + (bounds.height + 4) * partProgress,
          ),
          Paint()
            ..color = completedColor
            ..style = PaintingStyle.fill,
        );
        canvas.restore();
      }
      // تبقى الحدود المتقطعة فوق التعبئة لتوضح المسار بدقة للطفل.
      _AlifGuideGeometry.paintOutline(canvas, size);
    } else {
      for (var i = 0; i < strokes.length; i++) {
        final strokeProgress = progressFor(i);
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
          canvas.drawCircle(center, currentStrokeWidth * .72,
              Paint()..color = completedColor);
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
    required this.letter,
    required this.strokes,
  });

  final String letter;
  final List<StrokeSpec> strokes;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _LetterGuideBackdrop(letter: letter),
        CustomPaint(
          painter: _StrokesPainter(
            letter: letter,
            strokes: strokes,
            progress: 1,
            completedColor: AppColors.letterTraced,
          ),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

/// دليل الألف المتجهي: الحدود نفسها هي قناع التعبئة، لذلك لا يمكن للون
/// الأخضر أن يتجاوز شكل الحرف أو يترك فراغات عشوائية داخله.
class _LetterGuideBackdrop extends StatelessWidget {
  const _LetterGuideBackdrop({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    if (!letter.startsWith('أ')) return const SizedBox.shrink();
    return const IgnorePointer(
      child: CustomPaint(
        painter: _AlifGuidePainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _AlifGuidePainter extends CustomPainter {
  const _AlifGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _AlifGuideGeometry.paintOutline(canvas, size);
  }

  @override
  bool shouldRepaint(_AlifGuidePainter oldDelegate) => false;
}

/// هندسة واحدة مشتركة بين الحد المتقطع والتعبئة، مرتبة تربويًا:
/// الفتحة، ثم الهمزة، ثم جسم الألف.
abstract final class _AlifGuideGeometry {
  static Rect drawingRect(Size size) {
    const aspectRatio = .55;
    const widthFactor = .50;
    const heightFactor = .92;
    final width = math.min(
      size.width * widthFactor,
      size.height * heightFactor * aspectRatio,
    );
    final height = width / aspectRatio;
    return Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
  }

  static Offset _p(Rect rect, double x, double y) => Offset(
        rect.left + rect.width * x,
        rect.top + rect.height * y,
      );

  static List<Path> parts(Size size) {
    final rect = drawingRect(size);

    final fatha = Path()
      ..moveTo(_p(rect, .62, .006).dx, _p(rect, .62, .006).dy)
      ..cubicTo(
        _p(rect, .57, .014).dx,
        _p(rect, .57, .014).dy,
        _p(rect, .48, .040).dx,
        _p(rect, .48, .040).dy,
        _p(rect, .41, .060).dx,
        _p(rect, .41, .060).dy,
      )
      ..lineTo(_p(rect, .43, .075).dx, _p(rect, .43, .075).dy)
      ..cubicTo(
        _p(rect, .50, .058).dx,
        _p(rect, .50, .058).dy,
        _p(rect, .58, .040).dx,
        _p(rect, .58, .040).dy,
        _p(rect, .61, .030).dx,
        _p(rect, .61, .030).dy,
      )
      ..close();

    final hamza = Path()
      ..moveTo(_p(rect, .54, .082).dx, _p(rect, .54, .082).dy)
      ..cubicTo(
        _p(rect, .61, .082).dx,
        _p(rect, .61, .082).dy,
        _p(rect, .66, .110).dx,
        _p(rect, .66, .110).dy,
        _p(rect, .65, .145).dx,
        _p(rect, .65, .145).dy,
      )
      ..cubicTo(
        _p(rect, .64, .178).dx,
        _p(rect, .64, .178).dy,
        _p(rect, .60, .190).dx,
        _p(rect, .60, .190).dy,
        _p(rect, .54, .180).dx,
        _p(rect, .54, .180).dy,
      )
      ..lineTo(_p(rect, .48, .165).dx, _p(rect, .48, .165).dy)
      ..cubicTo(
        _p(rect, .44, .158).dx,
        _p(rect, .44, .158).dy,
        _p(rect, .41, .168).dx,
        _p(rect, .41, .168).dy,
        _p(rect, .43, .187).dx,
        _p(rect, .43, .187).dy,
      )
      ..cubicTo(
        _p(rect, .47, .210).dx,
        _p(rect, .47, .210).dy,
        _p(rect, .56, .207).dx,
        _p(rect, .56, .207).dy,
        _p(rect, .64, .185).dx,
        _p(rect, .64, .185).dy,
      )
      ..lineTo(_p(rect, .62, .220).dx, _p(rect, .62, .220).dy)
      ..cubicTo(
        _p(rect, .53, .245).dx,
        _p(rect, .53, .245).dy,
        _p(rect, .43, .245).dx,
        _p(rect, .43, .245).dy,
        _p(rect, .34, .258).dx,
        _p(rect, .34, .258).dy,
      )
      ..lineTo(_p(rect, .36, .226).dx, _p(rect, .36, .226).dy)
      ..cubicTo(
        _p(rect, .39, .213).dx,
        _p(rect, .39, .213).dy,
        _p(rect, .41, .204).dx,
        _p(rect, .41, .204).dy,
        _p(rect, .44, .194).dx,
        _p(rect, .44, .194).dy,
      )
      ..cubicTo(
        _p(rect, .38, .176).dx,
        _p(rect, .38, .176).dy,
        _p(rect, .36, .143).dx,
        _p(rect, .36, .143).dy,
        _p(rect, .39, .113).dx,
        _p(rect, .39, .113).dy,
      )
      ..cubicTo(
        _p(rect, .43, .080).dx,
        _p(rect, .43, .080).dy,
        _p(rect, .50, .074).dx,
        _p(rect, .50, .074).dy,
        _p(rect, .54, .082).dx,
        _p(rect, .54, .082).dy,
      )
      ..close();

    // الفراغ الداخلي جزء من بنية الهمزة؛ إضافته يمنع تحولها إلى دائرة
    // ممتلئة ويحافظ على شكلها العربي عند التلوين.
    final hamzaHole = Path()
      ..moveTo(_p(rect, .47, .112).dx, _p(rect, .47, .112).dy)
      ..cubicTo(
        _p(rect, .51, .099).dx,
        _p(rect, .51, .099).dy,
        _p(rect, .58, .113).dx,
        _p(rect, .58, .113).dy,
        _p(rect, .62, .139).dx,
        _p(rect, .62, .139).dy,
      )
      ..cubicTo(
        _p(rect, .59, .158).dx,
        _p(rect, .59, .158).dy,
        _p(rect, .54, .164).dx,
        _p(rect, .54, .164).dy,
        _p(rect, .49, .148).dx,
        _p(rect, .49, .148).dy,
      )
      ..cubicTo(
        _p(rect, .46, .138).dx,
        _p(rect, .46, .138).dy,
        _p(rect, .44, .122).dx,
        _p(rect, .44, .122).dy,
        _p(rect, .47, .112).dx,
        _p(rect, .47, .112).dy,
      )
      ..close();
    hamza
      ..fillType = PathFillType.evenOdd
      ..addPath(hamzaHole, Offset.zero);

    final body = Path()
      ..moveTo(_p(rect, .52, .268).dx, _p(rect, .52, .268).dy)
      ..lineTo(_p(rect, .60, .302).dx, _p(rect, .60, .302).dy)
      ..cubicTo(
        _p(rect, .56, .455).dx,
        _p(rect, .56, .455).dy,
        _p(rect, .58, .670).dx,
        _p(rect, .58, .670).dy,
        _p(rect, .56, .805).dx,
        _p(rect, .56, .805).dy,
      )
      ..cubicTo(
        _p(rect, .55, .875).dx,
        _p(rect, .55, .875).dy,
        _p(rect, .52, .918).dx,
        _p(rect, .52, .918).dy,
        _p(rect, .47, .940).dx,
        _p(rect, .47, .940).dy,
      )
      ..lineTo(_p(rect, .43, .912).dx, _p(rect, .43, .912).dy)
      ..cubicTo(
        _p(rect, .48, .805).dx,
        _p(rect, .48, .805).dy,
        _p(rect, .48, .660).dx,
        _p(rect, .48, .660).dy,
        _p(rect, .46, .500).dx,
        _p(rect, .46, .500).dy,
      )
      ..cubicTo(
        _p(rect, .45, .405).dx,
        _p(rect, .45, .405).dy,
        _p(rect, .43, .330).dx,
        _p(rect, .43, .330).dy,
        _p(rect, .45, .295).dx,
        _p(rect, .45, .295).dy,
      )
      ..close();

    return [fatha, hamza, body];
  }

  static void paintOutline(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink.withValues(alpha: .64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.shortestSide * .006).clamp(1.4, 2.4)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dash = (size.shortestSide * .020).clamp(4.0, 8.0);
    final gap = dash * .72;
    for (final path in parts(size)) {
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final end = math.min(distance + dash, metric.length);
          canvas.drawPath(metric.extractPath(distance, end), paint);
          distance += dash + gap;
        }
      }
    }
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
