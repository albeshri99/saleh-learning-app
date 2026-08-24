import 'dart:ui';
import 'dart:math' as math;

/// ضربة واحدة من ضربات كتابة الحرف، بإحداثيات منسوبة (0..1)
/// كما تأتي من المحتوى — مستقلة تمامًا عن مقاس الشاشة.
class StrokeSpec {
  const StrokeSpec.path(this.points)
      : kind = StrokeKind.path,
        center = null;

  const StrokeSpec.dot(this.center)
      : kind = StrokeKind.dot,
        points = const [];

  final StrokeKind kind;
  final List<Offset> points;
  final Offset? center;

  factory StrokeSpec.fromJson(Map<String, dynamic> json) {
    if (json['kind'] == 'dot') {
      final c = (json['center'] as List).cast<num>();
      return StrokeSpec.dot(Offset(c[0].toDouble(), c[1].toDouble()));
    }
    final pts = (json['points'] as List).map((p) {
      final l = (p as List).cast<num>();
      return Offset(l[0].toDouble(), l[1].toDouble());
    }).toList();
    return StrokeSpec.path(pts);
  }

  static List<StrokeSpec> listFromJson(List<dynamic>? raw) => (raw ?? const [])
      .map((e) => StrokeSpec.fromJson(e as Map<String, dynamic>))
      .toList();

  /// مسار مرسوم فعليًا داخل مساحة [size]، بمنحنيات ناعمة بين النقاط.
  Path scaledPath(Size size) {
    final path = Path();
    // لا نمدد الحرف على كامل السبورة؛ ذلك كان يحول «ث» إلى قوس مسطح.
    // نحافظ على نسبة خط عربي ثابتة ونوسّط الحرف مهما تغيّر مقاس الشاشة.
    // الثاء العربي عريض نسبةً إلى ارتفاعه. النسبة القديمة 1.55 كانت
    // تصغّره إلى رمز صغير وسط السبورة؛ 3.6 يمنحه عرض نموذج الدليل
    // مع إبقاء النقاط والجسم كاملين داخل ارتفاع شاشة الهاتف.
    const letterAspectRatio = 3.6;
    final drawWidth = math.min(
      size.width * .84,
      size.height * .88 * letterAspectRatio,
    );
    final drawHeight = drawWidth / letterAspectRatio;
    final origin = Offset(
      (size.width - drawWidth) / 2,
      (size.height - drawHeight) / 2,
    );
    Offset scalePoint(Offset point) => Offset(
          origin.dx + point.dx * drawWidth,
          origin.dy + point.dy * drawHeight,
        );
    if (kind == StrokeKind.dot) {
      final c = scalePoint(center!);
      // نقاط الثاء يجب أن تقرأ كدوائر خطية واضحة، لا كنقاط صغيرة
      // تختفي داخل سماكة جسم الحرف.
      path.addOval(Rect.fromCircle(center: c, radius: drawHeight * 0.075));
      return path;
    }
    final pts = points.map(scalePoint).toList();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  /// عينات متساوية البعد على المسار — أساس التتبع الموجه.
  List<Offset> samples(Size size, {int count = 40}) {
    if (kind == StrokeKind.dot) {
      final path = scaledPath(size);
      final bounds = path.getBounds();
      return [bounds.center];
    }
    final metrics = scaledPath(size).computeMetrics().toList();
    final result = <Offset>[];
    for (final m in metrics) {
      for (var i = 0; i <= count; i++) {
        final tangent = m.getTangentForOffset(m.length * i / count);
        if (tangent != null) result.add(tangent.position);
      }
    }
    return result;
  }
}

enum StrokeKind { path, dot }

