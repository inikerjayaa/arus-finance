import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SakuBrand {
  const SakuBrand._();

  static const String appName = 'SAKU';
  static const String fontFamily = 'PlusJakartaSans';

  static const Color noturno = Color(0xFF001621);
  static const Color vulcanico = Color(0xFFFF4103);
  static const Color sand = Color(0xFFF0EDE4);
  static const Color peach = Color(0xFFFFC3A4);
  static const Color white = Color(0xFFFFFFFF);
}

class SakuLaunchSplash extends StatelessWidget {
  const SakuLaunchSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: SakuBrand.noturno,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: SakuBrand.noturno,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: const ColoredBox(
        color: SakuBrand.noturno,
        child: SafeArea(
          child: Center(
            child: Semantics(
              image: true,
              label: 'SAKU',
              child: _SakuSplashLockup(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SakuSplashLockup extends StatelessWidget {
  const _SakuSplashLockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SakuPocketMark(size: 126),
        SizedBox(height: 22),
        Text(
          'SAKU',
          style: TextStyle(
            color: SakuBrand.white,
            fontFamily: SakuBrand.fontFamily,
            fontSize: 44,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.2,
          ),
        ),
      ],
    );
  }
}

class SakuPocketMark extends StatelessWidget {
  const SakuPocketMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _SakuPocketPainter(),
    );
  }
}

class _SakuPocketPainter extends CustomPainter {
  const _SakuPocketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 100;
    canvas.save();
    canvas.scale(sx, sy);

    final dark = Paint()
      ..color = SakuBrand.noturno
      ..style = PaintingStyle.fill;
    final orange = Paint()
      ..color = SakuBrand.vulcanico
      ..style = PaintingStyle.fill;
    final orangeShade = Paint()
      ..color = const Color(0xFFE63800)
      ..style = PaintingStyle.fill;
    final skin = Paint()
      ..color = SakuBrand.peach
      ..style = PaintingStyle.fill;
    final white = Paint()
      ..color = SakuBrand.white
      ..style = PaintingStyle.fill;

    final pocket = Path()
      ..moveTo(18, 48)
      ..quadraticBezierTo(50, 41, 82, 48)
      ..lineTo(80, 80)
      ..quadraticBezierTo(77, 90, 66, 92)
      ..lineTo(34, 92)
      ..quadraticBezierTo(22, 90, 20, 80)
      ..close();
    canvas.drawPath(pocket, orange);

    final shade = Path()
      ..moveTo(64, 45)
      ..quadraticBezierTo(82, 49, 82, 63)
      ..lineTo(80, 80)
      ..quadraticBezierTo(78, 89, 67, 92)
      ..lineTo(57, 92)
      ..quadraticBezierTo(70, 75, 64, 45)
      ..close();
    canvas.drawPath(shade, orangeShade);

    final arm = Path()
      ..moveTo(42, 13)
      ..lineTo(62, 17)
      ..quadraticBezierTo(58, 31, 61, 48)
      ..quadraticBezierTo(52, 52, 38, 48)
      ..quadraticBezierTo(43, 31, 42, 13)
      ..close();
    canvas.drawPath(arm, skin);

    final cuff = RRect.fromRectAndRadius(
      const Rect.fromLTWH(34, 5, 35, 19),
      const Radius.circular(6),
    );
    canvas.drawRRect(cuff, white);

    final cuffLine = Paint()
      ..color = SakuBrand.noturno
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(39, 21), const Offset(65, 23), cuffLine);

    final opening = Paint()
      ..color = SakuBrand.noturno
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    final openingPath = Path()
      ..moveTo(22, 51)
      ..quadraticBezierTo(50, 58, 77, 50);
    canvas.drawPath(openingPath, opening);

    final stitch = Paint()
      ..color = SakuBrand.noturno
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final segment in const [
      [26.0, 63.0, 34.0, 63.0],
      [39.0, 63.0, 47.0, 62.0],
      [52.0, 61.0, 60.0, 59.5],
      [65.0, 58.0, 72.0, 55.5],
    ]) {
      canvas.drawLine(
        Offset(segment[0], segment[1]),
        Offset(segment[2], segment[3]),
        stitch,
      );
    }

    canvas.drawCircle(const Offset(74.5, 52.5), 4.1, dark);

    final accent = Paint()
      ..color = SakuBrand.vulcanico
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(70, 32), const Offset(73, 22), accent);
    canvas.drawLine(const Offset(78, 36), const Offset(87, 29), accent);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
