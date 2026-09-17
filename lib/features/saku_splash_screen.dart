import 'package:flutter/material.dart';

import '../shared/saku_brand.dart';

class SakuSplashScreen extends StatelessWidget {
  const SakuSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: SakuBrand.noturno,
      body: SafeArea(
        child: Center(
          child: Semantics(
            container: true,
            label: 'SAKU sedang dibuka',
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SakuPocketMark(size: 132),
                SizedBox(height: 22),
                Text(
                  'SAKU',
                  style: TextStyle(
                    color: SakuBrand.white,
                    fontFamily: SakuBrand.fontFamily,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.0,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SakuPocketMark extends StatelessWidget {
  const _SakuPocketMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SakuPocketPainter()),
    );
  }
}

class _SakuPocketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 132;
    final sy = size.height / 132;
    canvas.save();
    canvas.scale(sx, sy);

    final dark = Paint()
      ..color = SakuBrand.noturno
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pocket = Path()
      ..moveTo(23, 63)
      ..quadraticBezierTo(63, 51, 108, 60)
      ..lineTo(108, 93)
      ..quadraticBezierTo(107, 116, 84, 121)
      ..lineTo(47, 121)
      ..quadraticBezierTo(24, 117, 23, 94)
      ..close();
    canvas.drawPath(
      pocket,
      Paint()
        ..color = SakuBrand.vulcanico
        ..style = PaintingStyle.fill,
    );

    final pocketShade = Path()
      ..moveTo(93, 60)
      ..quadraticBezierTo(110, 65, 108, 93)
      ..quadraticBezierTo(107, 113, 91, 119)
      ..quadraticBezierTo(100, 98, 93, 60)
      ..close();
    canvas.drawPath(
      pocketShade,
      Paint()
        ..color = const Color(0xFFE63800)
        ..style = PaintingStyle.fill,
    );

    final arm = Path()
      ..moveTo(44, 23)
      ..lineTo(68, 16)
      ..lineTo(83, 62)
      ..quadraticBezierTo(70, 72, 52, 68)
      ..close();
    canvas.drawPath(
      arm,
      Paint()
        ..color = const Color(0xFFFFC09D)
        ..style = PaintingStyle.fill,
    );

    final sleeve = RRect.fromRectAndRadius(
      const Rect.fromLTWH(34, 8, 45, 27),
      const Radius.circular(8),
    );
    canvas.save();
    canvas.translate(56, 21);
    canvas.rotate(-0.22);
    canvas.translate(-56, -21);
    canvas.drawRRect(
      sleeve,
      Paint()
        ..color = SakuBrand.white
        ..style = PaintingStyle.fill,
    );
    dark
      ..strokeWidth = 5
      ..color = SakuBrand.noturno;
    canvas.drawLine(const Offset(38, 32), const Offset(76, 32), dark);
    canvas.restore();

    dark
      ..strokeWidth = 5
      ..color = SakuBrand.noturno;
    final opening = Path()
      ..moveTo(25, 64)
      ..quadraticBezierTo(63, 78, 105, 61);
    canvas.drawPath(opening, dark);

    dark
      ..strokeWidth = 4
      ..color = SakuBrand.noturno;
    for (final x in <double>[32, 45, 58, 71, 84]) {
      canvas.drawLine(Offset(x, 79), Offset(x + 6, 78), dark);
    }

    canvas.drawCircle(
      const Offset(99, 69),
      5,
      Paint()
        ..color = SakuBrand.noturno
        ..style = PaintingStyle.fill,
    );

    final accent = Paint()
      ..color = SakuBrand.vulcanico
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(89, 47), const Offset(96, 36), accent);
    canvas.drawLine(const Offset(99, 52), const Offset(109, 44), accent);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SakuPocketPainter oldDelegate) => false;
}
