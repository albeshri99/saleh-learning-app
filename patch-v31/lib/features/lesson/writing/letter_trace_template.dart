import 'dart:math' as math;
import 'dart:ui';

import 'letter_strokes.dart';

/// A single geometric source for a letter's outline and writing motion.
///
/// The same template is used by the demonstration, guided tracing, completed
/// state, and free-writing verifier. This prevents the glyph from changing
/// shape when its state changes.
class LetterTraceTemplate {
  const LetterTraceTemplate({
    required this.id,
    required this.aspectRatio,
    required this.widthFactor,
    required this.heightFactor,
    required this.parts,
  });

  final String id;
  final double aspectRatio;
  final double widthFactor;
  final double heightFactor;
  final List<LetterTracePart> parts;

  Rect drawingRect(Size size) {
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

  List<StrokeSpec> get strokes => parts
      .map(
        (part) => StrokeSpec.path(
          part.centerline,
          aspectRatio: aspectRatio,
          widthFactor: widthFactor,
          heightFactor: heightFactor,
        ),
      )
      .toList(growable: false);

  /// عينات متساوية المسافة من المنحنى الحقيقي للقالب.
  ///
  /// كان المؤشر سابقًا يأخذ عيناته من نقاط [StrokeSpec] التقريبية، بينما
  /// تعبئة اللون تتبع [LetterTracePart.centerlinePath]. ظهر الفرق بوضوح داخل
  /// التفاف الهمزة. استخدام المصدر نفسه هنا يجعل المؤشر والتعبئة متطابقين.
  List<Offset> samples(Size size, int partIndex, {int count = 40}) {
    if (partIndex < 0 || partIndex >= parts.length) return const [];
    return parts[partIndex].samples(drawingRect(size), count: count);
  }

  static LetterTraceTemplate? fromId(String? id) {
    if (id == alifFathaVideoTemplate.id) return alifFathaVideoTemplate;
    return null;
  }
}

class LetterTracePart {
  const LetterTracePart({
    required this.id,
    required this.outline,
    required this.centerline,
    required this.revealWidthFactor,
    this.smoothOutline = false,
  });

  final String id;
  final List<Offset> outline;
  final List<Offset> centerline;

  /// Reveal brush width relative to the template drawing rectangle width.
  final double revealWidthFactor;
  final bool smoothOutline;

  Offset _scale(Rect rect, Offset p) => Offset(
        rect.left + p.dx * rect.width,
        rect.top + p.dy * rect.height,
      );

  Path outlinePath(Rect rect) {
    final points = outline.map((p) => _scale(rect, p)).toList(growable: false);
    if (points.isEmpty) return Path();
    if (!smoothOutline || points.length < 4) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      return path..close();
    }

    Offset midpoint(Offset a, Offset b) =>
        Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final path = Path();
    final firstMid = midpoint(points.last, points.first);
    path.moveTo(firstMid.dx, firstMid.dy);
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final nextMid = midpoint(current, next);
      path.quadraticBezierTo(
        current.dx,
        current.dy,
        nextMid.dx,
        nextMid.dy,
      );
    }
    return path..close();
  }

  Path centerlinePath(Rect rect) {
    final points =
        centerline.map((p) => _scale(rect, p)).toList(growable: false);
    if (points.isEmpty) return Path();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middle = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        middle.dx,
        middle.dy,
      );
    }
    final last = points.last;
    return path..lineTo(last.dx, last.dy);
  }

  /// عينات متساوية المسافة على المنحنى نفسه المستخدم في تعبئة الحرف.
  List<Offset> samples(Rect rect, {int count = 40}) {
    final metrics = centerlinePath(rect).computeMetrics().toList();
    if (metrics.isEmpty) return const [];
    final result = <Offset>[];
    for (final metric in metrics) {
      for (var i = 0; i <= count; i++) {
        final tangent = metric.getTangentForOffset(metric.length * i / count);
        if (tangent != null) result.add(tangent.position);
      }
    }
    return result;
  }
}

/// Exact proportions traced from the user's 336×512 reference video.
///
/// Order follows the video: alif body top-to-bottom, hamza, then fatha from
/// right to left. The outline never changes; only a clipped colour reveal is
/// animated inside it.
const alifFathaVideoTemplate = LetterTraceTemplate(
  id: 'alif_fatha_video_v1',
  aspectRatio: 2 / 7,
  widthFactor: .50,
  heightFactor: .94,
  parts: [
    LetterTracePart(
      id: 'body',
      revealWidthFactor: .38,
      outline: [
        Offset(.5917, .3643),
        Offset(.3583, .4357),
        Offset(.4083, .5881),
        Offset(.4333, .7810),
        Offset(.4250, .9190),
        Offset(.4000, .9690),
        Offset(.4333, .9762),
        Offset(.5083, .9548),
        Offset(.6167, .9071),
        Offset(.6500, .8738),
        Offset(.6667, .8333),
        Offset(.6667, .5310),
        Offset(.6167, .3786),
      ],
      centerline: [
        Offset(.5833, .3738),
        Offset(.5500, .4000),
        Offset(.5250, .4405),
        Offset(.5083, .5000),
        Offset(.4917, .5952),
        Offset(.4833, .7143),
        Offset(.4833, .8333),
        Offset(.4667, .9048),
        Offset(.4250, .9548),
      ],
    ),
    LetterTracePart(
      id: 'hamza',
      revealWidthFactor: .28,
      outline: [
        Offset(.6333, .1643),
        Offset(.5750, .1571),
        Offset(.5000, .1571),
        Offset(.4083, .1643),
        Offset(.3083, .1810),
        Offset(.1917, .2167),
        Offset(.1500, .2429),
        Offset(.1500, .2690),
        Offset(.1750, .2833),
        Offset(.2750, .3048),
        Offset(.1917, .3476),
        Offset(.2083, .3524),
        Offset(.3333, .3357),
        Offset(.4667, .3238),
        Offset(.7250, .3119),
        Offset(.7583, .3000),
        Offset(.8167, .2643),
        Offset(.8083, .2595),
        Offset(.4750, .2595),
        Offset(.3667, .2476),
        Offset(.3250, .2357),
        Offset(.3250, .2238),
        Offset(.3583, .2143),
        Offset(.4167, .2071),
        Offset(.5083, .2071),
        Offset(.6000, .2333),
        Offset(.6167, .2333),
        Offset(.6750, .2024),
        Offset(.6750, .1786),
      ],
      centerline: [
        Offset(.5833, .1714),
        Offset(.5000, .1714),
        Offset(.4167, .1738),
        Offset(.3333, .1810),
        Offset(.2667, .2000),
        Offset(.2250, .2143),
        Offset(.2083, .2333),
        Offset(.2250, .2524),
        Offset(.2750, .2667),
        Offset(.3333, .2810),
        Offset(.4167, .2929),
        Offset(.5417, .2976),
        Offset(.6667, .2976),
        Offset(.7500, .2810),
      ],
    ),
    LetterTracePart(
      id: 'fatha',
      revealWidthFactor: .27,
      outline: [
        Offset(.8917, .0286),
        Offset(.5500, .0643),
        Offset(.1417, .1000),
        Offset(.0917, .1548),
        Offset(.1083, .1571),
        Offset(.4583, .1238),
        Offset(.8000, .0857),
      ],
      centerline: [
        Offset(.8167, .0429),
        Offset(.6667, .0643),
        Offset(.4583, .0881),
        Offset(.2500, .1143),
        Offset(.1250, .1381),
      ],
    ),
  ],
);
