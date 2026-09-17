import 'package:flutter/material.dart';

import 'saku_brand.dart';

class SakuSplashScreen extends StatelessWidget {
  const SakuSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakuBrand.noturno,
      body: SafeArea(
        child: Center(
          child: Semantics(
            container: true,
            label: 'SAKU sedang dibuka',
            liveRegion: true,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(painter: _SakuPocketPainter()),
                ),
                SizedBox(height: 18),
                Text(
                  'SAKU',
                  style: TextStyle(
                    color: SakuBrand.onNoturno,
                    fontFamily: SakuBrand.fontFamily,
                    fontSize: 44,
                    height: 1,
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w800,
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

class _SakuPocketPainter extends CustomPainter {
  const _SakuPocketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()
      ..color = SakuBrand.noturno
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final orange = Paint()..color = SakuBrand.vulcanico;
    final orangeShade = Paint()..color = const Color(0xFFE83A02);
    final skin = Paint()..color = const Color(0xFFFFB48F);
    final white = Paint()..color = SakuBrand.onNoturno;

    final pocket = Path()
      ..moveTo(size.width * .20, size.height * .48)
      ..quadraticBezierTo(size.width * .50, size.height * .38,
          size.width * .80, size.height * .48)
      ..lineTo(size.width * .78, size.height * .78)
      ..quadraticBezierTo(size.width * .76, size.height * .91,
          size.width * .52, size.height * .92)
      ..lineTo(size.width * .38, size.height * .92)
      ..quadraticBezierTo(size.width * .20, size.height * .90,
          size.width * .19, size.height * .75)
      ..close();
    canvas.drawPath(pocket, orange);

    final shade = Path()
      ..moveTo(size.width * .70, size.height * .46)
      ..quadraticBezierTo(size.width * .86, size.height * .60,
          size.width * .75, size.height * .87)
      ..quadraticBezierTo(size.width * .67, size.height * .93,
          size.width * .59, size.height * .91)
      ..quadraticBezierTo(size.width * .74, size.height * .68,
          size.width * .70, size.height * .46)
      ..close();
    canvas.drawPath(shade, orangeShade);

    final arm = Path()
      ..moveTo(size.width * .38, size.height * .20)
      ..lineTo(size.width * .63, size.height * .30)
      ..lineTo(size.width * .61, size.height * .55)
      ..quadraticBezierTo(size.width * .50, size.height * .62,
          size.width * .35, size.height * .52)
      ..close();
    canvas.drawPath(arm, skin);

    final cuff = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .25,
        size.height * .05,
        size.width * .38,
        size.height * .24,
      ),
      Radius.circular(size.width * .06),
    );
    canvas.save();
    canvas.translate(size.width * .02, size.height * .05);
    canvas.rotate(-.18);
    canvas.drawRRect(cuff, white);
    canvas.restore();

    dark
      ..strokeWidth = size.width * .035
      ..color = SakuBrand.noturno;
    final opening = Path()
      ..moveTo(size.width * .23, size.height * .51)
      ..quadraticBezierTo(size.width * .49, size.height * .61,
          size.width * .77, size.height * .49);
    canvas.drawPath(opening, dark);

    dark.strokeWidth = size.width * .03;
    for (var i = 0; i < 5; i++) {
      final x = size.width * (.28 + i * .09);
      final y = size.height * (.67 - i * .006);
      canvas.drawLine(Offset(x, y), Offset(x + size.width * .045, y), dark);
    }

    canvas.drawCircle(
      Offset(size.width * .72, size.height * .60),
      size.width * .035,
      Paint()..color = SakuBrand.noturno,
    );

    final accent = Paint()
      ..color = SakuBrand.vulcanico
      ..strokeWidth = size.width * .045
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .72, size.height * .35),
      Offset(size.width * .75, size.height * .27),
      accent,
    );
    canvas.drawLine(
      Offset(size.width * .79, size.height * .40),
      Offset(size.width * .86, size.height * .35),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
