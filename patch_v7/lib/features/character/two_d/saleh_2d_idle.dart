import 'dart:math' as math;

import 'package:flutter/material.dart';

/// تجربة تحريك 2D لصالح من صورة شفافة واحدة.
///
/// نفصل الرأس والجسم بقناعين، ثم نحركهما بمفاتيح زمنية مستقلة. بهذه
/// الطريقة تبقى الملامح والملابس ثابتة ولا نحتاج فيديو أو كروما.
class Saleh2DIdle extends StatefulWidget {
  const Saleh2DIdle({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  State<Saleh2DIdle> createState() => _Saleh2DIdleState();
}

class _Saleh2DIdleState extends State<Saleh2DIdle>
    with SingleTickerProviderStateMixin {
  static const _asset =
      'assets/character/saleh_video/saleh_idle_alpha_poster.png';

  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return AnimatedBuilder(
            animation: _idle,
            builder: (context, _) {
              final phase = _idle.value * math.pi * 2;
              final breath = math.sin(phase);
              final sway = math.sin(phase * .5);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: size.height * .015,
                    child: Transform.scale(
                      scaleX: 1 - breath * .025,
                      scaleY: 1 + breath * .015,
                      child: Container(
                        width: size.width * .42,
                        height: size.height * .035,
                        decoration: BoxDecoration(
                          color: const Color(0x4D4F3526),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(color: Color(0x304F3526), blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // الجسم: ارتداد رأسي بالغ الخفة حول القدمين.
                  Transform.translate(
                    offset: Offset(0, -breath * size.height * .004),
                    child: Transform.scale(
                      alignment: Alignment.bottomCenter,
                      scaleX: 1 + breath * .004,
                      scaleY: 1 + breath * .006,
                      child: ClipPath(
                        clipper: const _BodyClipper(),
                        child: Image.asset(
                          _asset,
                          width: size.width,
                          height: size.height,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  // الرأس مستقل: ميل بسيط مثل تحريك النمر، بلا تشوه.
                  Transform.translate(
                    offset: Offset(
                      sway * size.width * .006,
                      -breath * size.height * .006,
                    ),
                    child: Transform.rotate(
                      alignment: const Alignment(0, -.22),
                      angle: sway * .012,
                      child: ClipPath(
                        clipper: const _HeadClipper(),
                        child: Image.asset(
                          _asset,
                          width: size.width,
                          height: size.height,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

}

class _HeadClipper extends CustomClipper<Path> {
  const _HeadClipper();

  @override
  Path getClip(Size size) =>
      Path()..addRect(Rect.fromLTRB(0, 0, size.width, size.height * .365));

  @override
  bool shouldReclip(covariant _HeadClipper oldClipper) => false;
}

class _BodyClipper extends CustomClipper<Path> {
  const _BodyClipper();

  @override
  Path getClip(Size size) => Path()
    ..addRect(Rect.fromLTRB(0, size.height * .335, size.width, size.height));

  @override
  bool shouldReclip(covariant _BodyClipper oldClipper) => false;
}

