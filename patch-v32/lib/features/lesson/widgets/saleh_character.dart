import 'dart:math' as math;

import 'package:flutter/material.dart';

/// حالات صالح الحركية. عند اعتماد المقاطع التالية ستُربط هذه الأسماء
/// بحالات الـ State Machine نفسها، ويُستبدل جسم هذا الملف فقط —
/// لا يعرف أي مشهد ولا الهيكل شيئًا عن طريقة الرسم.
enum SalehPose {
  idle,
  talking,
  pointing,
  thinking,
  encouraging,
  celebrating,
  waving,
}

/// نسخة مرحلية مرسومة برمجيًا لشخصية صالح وفق الهوية المعتمدة:
/// شعر أسود كثيف، عيون كبيرة ودودة، ثوب أبيض بسيط، حذاء بني مريح،
/// مع تنفس خفيف، رمش، فم يتحرك أثناء الكلام، وذراع تشير/تلوّح/تحتفل.
class SalehSketchCharacter extends StatefulWidget {
  const SalehSketchCharacter({
    super.key,
    this.pose = SalehPose.idle,
    this.size = 260,
  });

  final SalehPose pose;
  final double size;

  @override
  State<SalehSketchCharacter> createState() => _SalehSketchCharacterState();
}

class _SalehSketchCharacterState extends State<SalehSketchCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

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
        size: Size(widget.size * 0.60, widget.size),
        painter: _SalehPainter(t: _c.value, pose: widget.pose),
      ),
    );
  }
}

class _SalehPainter extends CustomPainter {
  _SalehPainter({required this.t, required this.pose});

  final double t;
  final SalehPose pose;

  static const _skin = Color(0xFFF6C9A0);
  static const _skinShade = Color(0xFFEAB183);
  static const _hair = Color(0xFF2A211E);
  static const _thobe = Color(0xFFFDFCF8);
  static const _thobeShade = Color(0xFFEDE7DA);
  static const _shoe = Color(0xFF8A5A3B);
  static const _shoeDark = Color(0xFF6B4E3D);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wave = math.sin(t * 2 * math.pi);
    final cx = w / 2;
    final paint = Paint()..isAntiAlias = true;

    // ظل أرضي
    paint.color = const Color(0x1F6B4E3D);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.985),
        width: w * 0.72,
        height: h * 0.045,
      ),
      paint,
    );

    canvas.save();
    var bob = wave * 2.5;
    if (pose == SalehPose.celebrating || pose == SalehPose.encouraging) {
      bob -= 7 * (0.5 + 0.5 * wave);
    }
    canvas.translate(0, bob);

    // الحذاء البني
    for (final side in [-1, 1]) {
      paint.color = _shoe;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: Offset(cx + side * w * 0.13, h * 0.955),
            width: w * 0.20,
            height: h * 0.045,
          ),
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
          bottomLeft: const Radius.circular(6),
          bottomRight: const Radius.circular(6),
        ),
        paint,
      );
      paint.color = _shoeDark;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + side * w * 0.13, h * 0.975),
            width: w * 0.22,
            height: h * 0.015,
          ),
          const Radius.circular(4),
        ),
        paint,
      );
    }

    // الثوب الأبيض
    final bodyTop = h * 0.40;
    final body = Path()
      ..moveTo(cx - w * 0.15, bodyTop)
      ..quadraticBezierTo(cx - w * 0.33, h * 0.72, cx - w * 0.28, h * 0.95)
      ..lineTo(cx + w * 0.28, h * 0.95)
      ..quadraticBezierTo(cx + w * 0.33, h * 0.72, cx + w * 0.15, bodyTop)
      ..close();
    paint.color = _thobe;
    canvas.drawPath(body, paint);
    // ظل جانبي ناعم على الثوب
    paint.color = _thobeShade;
    canvas.drawPath(
      Path()
        ..moveTo(cx + w * 0.06, bodyTop + h * 0.02)
        ..quadraticBezierTo(cx + w * 0.29, h * 0.72, cx + w * 0.22, h * 0.95)
        ..lineTo(cx + w * 0.28, h * 0.95)
        ..quadraticBezierTo(cx + w * 0.33, h * 0.72, cx + w * 0.15, bodyTop)
        ..close(),
      paint,
    );
    // ياقة وجيب
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _thobeShade;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, bodyTop + h * 0.01),
        width: w * 0.16,
        height: h * 0.05,
      ),
      0,
      math.pi,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(cx, bodyTop + h * 0.03),
      Offset(cx, bodyTop + h * 0.12),
      paint,
    );
    paint.style = PaintingStyle.fill;

    // الذراع اليمنى (تشير/تلوّح/تحتفل/ترتاح)
    final shoulder = Offset(cx + w * 0.13, h * 0.47);
    double armAngle;
    switch (pose) {
      case SalehPose.pointing:
        armAngle = -1.25;
      case SalehPose.thinking:
        armAngle = -0.82;
      case SalehPose.waving:
        armAngle = -1.95 + wave * 0.28;
      case SalehPose.celebrating:
        armAngle = -2.2 + wave * 0.15;
      case SalehPose.encouraging:
        armAngle = -1.15 + wave * 0.12;
      case SalehPose.talking:
        armAngle = -0.6 + wave * 0.09;
      case SalehPose.idle:
        armAngle = -0.28;
    }
    final armLen = h * 0.235;
    final hand = shoulder +
        Offset(math.sin(-armAngle) * armLen, math.cos(-armAngle) * armLen);
    paint
      ..color = _thobe
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.125
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(shoulder, hand, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = _skin;
    canvas.drawCircle(hand, w * 0.055, paint);

    // الذراع اليسرى الثانية عند الاحتفال
    if (pose == SalehPose.celebrating) {
      final shoulderL = Offset(cx - w * 0.13, h * 0.47);
      final handL = shoulderL +
          Offset(
            -math.sin(2.2 - wave * 0.15) * armLen,
            math.cos(2.2 - wave * 0.15) * armLen,
          );
      paint
        ..color = _thobe
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.125
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(shoulderL, handL, paint);
      paint
        ..style = PaintingStyle.fill
        ..color = _skin;
      canvas.drawCircle(handL, w * 0.055, paint);
    }

    // مؤشر التعليم الخشبي عند الإشارة
    if (pose == SalehPose.pointing) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round
        ..color = _shoe;
      final dir = (hand - shoulder);
      final unit = dir / dir.distance;
      canvas.drawLine(hand, hand + unit * (h * 0.14), paint);
      paint.style = PaintingStyle.fill;
    }

    // الرقبة
    paint.color = _skinShade;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, h * 0.385),
        width: w * 0.12,
        height: h * 0.04,
      ),
      paint,
    );

    // الرأس — كبير ودود (نِسَب طفولية)
    final headC = Offset(cx, h * 0.225);
    final headR = w * 0.315;
    paint.color = _skin;
    canvas.drawOval(
      Rect.fromCenter(center: headC, width: headR * 2.05, height: headR * 2.15),
      paint,
    );

    // الأذنان
    for (final side in [-1, 1]) {
      paint.color = _skin;
      canvas.drawCircle(
        Offset(headC.dx + side * headR * 1.0, headC.dy + headR * 0.08),
        headR * 0.16,
        paint,
      );
    }

    // الشعر الأسود الكثيف المتموج — حجم وافر يغطي أعلى الرأس والجانبين
    paint.color = _hair;
    final hairPath = Path()
      ..moveTo(headC.dx - headR * 1.10, headC.dy + headR * 0.30)
      ..quadraticBezierTo(
        headC.dx - headR * 1.30,
        headC.dy - headR * 0.85,
        headC.dx - headR * 0.45,
        headC.dy - headR * 1.12,
      )
      ..quadraticBezierTo(
        headC.dx,
        headC.dy - headR * 1.42,
        headC.dx + headR * 0.55,
        headC.dy - headR * 1.08,
      )
      ..quadraticBezierTo(
        headC.dx + headR * 1.30,
        headC.dy - headR * 0.70,
        headC.dx + headR * 1.10,
        headC.dy + headR * 0.30,
      )
      ..quadraticBezierTo(
        headC.dx + headR * 1.02,
        headC.dy - headR * 0.05,
        headC.dx + headR * 0.80,
        headC.dy - headR * 0.18,
      )
      ..quadraticBezierTo(
        headC.dx + headR * 0.45,
        headC.dy - headR * 0.55,
        headC.dx - headR * 0.05,
        headC.dy - headR * 0.38,
      )
      ..quadraticBezierTo(
        headC.dx - headR * 0.55,
        headC.dy - headR * 0.28,
        headC.dx - headR * 0.80,
        headC.dy - headR * 0.02,
      )
      ..quadraticBezierTo(
        headC.dx - headR * 0.98,
        headC.dy + headR * 0.12,
        headC.dx - headR * 1.10,
        headC.dy + headR * 0.30,
      )
      ..close();
    canvas.drawPath(hairPath, paint);
    // خصلات أمامية متموجة
    for (final (sx, ex) in [(-0.05, 0.45), (-0.45, 0.05)]) {
      canvas.drawPath(
        Path()
          ..moveTo(headC.dx + headR * sx, headC.dy - headR * 0.38)
          ..quadraticBezierTo(
            headC.dx + headR * (sx + ex) / 2,
            headC.dy - headR * 0.78,
            headC.dx + headR * ex,
            headC.dy - headR * 0.45,
          )
          ..quadraticBezierTo(
            headC.dx + headR * (sx + ex) / 2,
            headC.dy - headR * 0.35,
            headC.dx + headR * sx,
            headC.dy - headR * 0.38,
          )
          ..close(),
        paint,
      );
    }

    // العينان الكبيرتان الودودتان
    final blink = (t % 1) > 0.93 ? 0.12 : 1.0;
    for (final side in [-1, 1]) {
      final eyeC = Offset(
        headC.dx + side * headR * 0.40,
        headC.dy - headR * 0.02,
      );
      // بياض العين — عيون كبيرة ودودة كما في الهوية
      paint.color = Colors.white;
      canvas.drawOval(
        Rect.fromCenter(
          center: eyeC,
          width: headR * 0.54,
          height: headR * 0.64 * blink,
        ),
        paint,
      );
      if (blink > 0.5) {
        // القزحية البنية الكبيرة
        paint.color = const Color(0xFF5B3A25);
        canvas.drawCircle(
          Offset(eyeC.dx, eyeC.dy + headR * 0.04),
          headR * 0.20,
          paint,
        );
        paint.color = const Color(0xFF2A1B10);
        canvas.drawCircle(
          Offset(eyeC.dx, eyeC.dy + headR * 0.04),
          headR * 0.10,
          paint,
        );
        // لمعتان
        paint.color = Colors.white;
        canvas.drawCircle(
          Offset(eyeC.dx + headR * 0.07, eyeC.dy - headR * 0.03),
          headR * 0.055,
          paint,
        );
        canvas.drawCircle(
          Offset(eyeC.dx - headR * 0.06, eyeC.dy + headR * 0.10),
          headR * 0.03,
          paint,
        );
      }
      // الحاجب
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.08
        ..strokeCap = StrokeCap.round
        ..color = _hair;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(eyeC.dx, eyeC.dy - headR * 0.30),
          radius: headR * 0.18,
        ),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        paint,
      );
      paint.style = PaintingStyle.fill;
    }

    // الخدان الورديان
    paint.color = const Color(0x33FF8A3D);
    for (final side in [-1, 1]) {
      canvas.drawCircle(
        Offset(headC.dx + side * headR * 0.62, headC.dy + headR * 0.30),
        headR * 0.13,
        paint,
      );
    }

    // الأنف الصغير
    paint.color = _skinShade;
    canvas.drawCircle(
      Offset(headC.dx, headC.dy + headR * 0.24),
      headR * 0.075,
      paint,
    );

    // الفم — مبتسم، ويتحرك أثناء الكلام
    final talking = pose == SalehPose.talking;
    final mouthOpen = talking ? (0.5 + 0.5 * math.sin(t * 10 * math.pi)) : 0.0;
    if (mouthOpen > 0.25) {
      paint.color = const Color(0xFF7E3428);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headC.dx, headC.dy + headR * 0.52),
          width: headR * 0.40,
          height: headR * (0.10 + 0.24 * mouthOpen),
        ),
        paint,
      );
      paint.color = Colors.white;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(headC.dx, headC.dy + headR * 0.45),
          width: headR * 0.26,
          height: headR * 0.05,
        ),
        paint,
      );
    } else {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.075
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF7E3428);
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(headC.dx, headC.dy + headR * 0.40),
          radius: headR * 0.26,
        ),
        math.pi * 0.12,
        math.pi * 0.76,
        false,
        paint,
      );
      paint.style = PaintingStyle.fill;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SalehPainter old) => old.t != t || old.pose != pose;
}
