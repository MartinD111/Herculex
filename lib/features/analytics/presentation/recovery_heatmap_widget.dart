import 'package:flutter/material.dart';

import '../domain/muscle_recovery.dart';

class RecoveryHeatmapWidget extends StatelessWidget {
  final List<MuscleRecoveryResult> recoveryList;

  const RecoveryHeatmapWidget({
    super.key,
    required this.recoveryList,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Map list to map for fast lookups
    final recoveryMap = {for (var r in recoveryList) r.muscle: r.score};

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            Text("FRONT", style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            CustomPaint(
              size: const Size(120, 240),
              painter: _SilhouettePainter(recoveryMap, isFront: true),
            ),
          ],
        ),
        Column(
          children: [
            Text("BACK", style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            CustomPaint(
              size: const Size(120, 240),
              painter: _SilhouettePainter(recoveryMap, isFront: false),
            ),
          ],
        ),
      ],
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  final Map<String, double> recoveryMap;
  final bool isFront;

  _SilhouettePainter(this.recoveryMap, {required this.isFront});

  Color _getColorForMuscle(String muscle) {
    final score = recoveryMap[muscle] ?? 0.0;
    if (score < 0.3) {
      return Colors.green.withValues(alpha: 0.3 + (score * 0.5));
    } else if (score < 0.7) {
      return Colors.amber.withValues(alpha: 0.4 + (score * 0.4));
    } else {
      return Colors.red.withValues(alpha: 0.5 + (score * 0.5));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final basePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw baseline full body silhouette placeholder (head, torso, arms, legs)
    final bodyOutline = Path()
      ..moveTo(width * 0.5, height * 0.02) // Top head
      ..quadraticBezierTo(width * 0.35, height * 0.02, width * 0.35, height * 0.08) // Left head
      ..quadraticBezierTo(width * 0.35, height * 0.12, width * 0.42, height * 0.14) // Neck left
      ..lineTo(width * 0.2, height * 0.18) // Shoulder left
      ..quadraticBezierTo(width * 0.05, height * 0.28, width * 0.15, height * 0.45) // Hand left outer
      ..quadraticBezierTo(width * 0.22, height * 0.45, width * 0.25, height * 0.32) // Hand left inner
      ..lineTo(width * 0.3, height * 0.32) // Rib left
      ..lineTo(width * 0.32, height * 0.55) // Hip left
      ..lineTo(width * 0.22, height * 0.95) // Foot left outer
      ..quadraticBezierTo(width * 0.3, height * 0.98, width * 0.38, height * 0.95) // Foot left inner
      ..lineTo(width * 0.5, height * 0.6) // Groin
      ..lineTo(width * 0.62, height * 0.95) // Foot right inner
      ..quadraticBezierTo(width * 0.7, height * 0.98, width * 0.78, height * 0.95) // Foot right outer
      ..lineTo(width * 0.68, height * 0.55) // Hip right
      ..lineTo(width * 0.7, height * 0.32) // Rib right
      ..lineTo(width * 0.75, height * 0.32) // Hand right inner
      ..quadraticBezierTo(width * 0.95, height * 0.45, width * 0.85, height * 0.45) // Hand right outer
      ..lineTo(width * 0.8, height * 0.18) // Shoulder right
      ..quadraticBezierTo(width * 0.65, height * 0.14, width * 0.58, height * 0.14) // Neck right
      ..quadraticBezierTo(width * 0.65, height * 0.12, width * 0.65, height * 0.08) // Right head
      ..close();

    canvas.drawPath(bodyOutline, basePaint);
    canvas.drawPath(bodyOutline, borderPaint);

    // Dynamic Muscle overlays
    if (isFront) {
      // Chest
      _drawMuscle(canvas, 'Chest', Path()
        ..moveTo(width * 0.35, height * 0.22)
        ..lineTo(width * 0.5, height * 0.22)
        ..lineTo(width * 0.5, height * 0.28)
        ..lineTo(width * 0.32, height * 0.28)
        ..close()
        ..moveTo(width * 0.65, height * 0.22)
        ..lineTo(width * 0.5, height * 0.22)
        ..lineTo(width * 0.5, height * 0.28)
        ..lineTo(width * 0.68, height * 0.28)
        ..close());

      // Abs
      _drawMuscle(canvas, 'Abs', Path()
        ..moveTo(width * 0.35, height * 0.3)
        ..lineTo(width * 0.65, height * 0.3)
        ..lineTo(width * 0.63, height * 0.42)
        ..lineTo(width * 0.37, height * 0.42)
        ..close());

      // Quads
      _drawMuscle(canvas, 'Quads', Path()
        ..moveTo(width * 0.28, height * 0.56)
        ..lineTo(width * 0.46, height * 0.56)
        ..lineTo(width * 0.44, height * 0.74)
        ..lineTo(width * 0.3, height * 0.74)
        ..close()
        ..moveTo(width * 0.72, height * 0.56)
        ..lineTo(width * 0.54, height * 0.56)
        ..lineTo(width * 0.56, height * 0.74)
        ..lineTo(width * 0.7, height * 0.74)
        ..close());
    } else {
      // Back
      _drawMuscle(canvas, 'Back', Path()
        ..moveTo(width * 0.33, height * 0.22)
        ..lineTo(width * 0.67, height * 0.22)
        ..lineTo(width * 0.63, height * 0.4)
        ..lineTo(width * 0.37, height * 0.4)
        ..close());

      // Hamstrings
      _drawMuscle(canvas, 'Hamstrings', Path()
        ..moveTo(width * 0.28, height * 0.56)
        ..lineTo(width * 0.46, height * 0.56)
        ..lineTo(width * 0.44, height * 0.74)
        ..lineTo(width * 0.3, height * 0.74)
        ..close()
        ..moveTo(width * 0.72, height * 0.56)
        ..lineTo(width * 0.54, height * 0.56)
        ..lineTo(width * 0.56, height * 0.74)
        ..lineTo(width * 0.7, height * 0.74)
        ..close());
    }

    // Shared: Shoulders
    _drawMuscle(canvas, 'Shoulders', Path()
      ..moveTo(width * 0.26, height * 0.16)
      ..quadraticBezierTo(width * 0.18, height * 0.2, width * 0.23, height * 0.26)
      ..close()
      ..moveTo(width * 0.74, height * 0.16)
      ..quadraticBezierTo(width * 0.82, height * 0.2, width * 0.77, height * 0.26)
      ..close());

    // Shared: Arms
    _drawMuscle(canvas, 'Arms', Path()
      ..moveTo(width * 0.21, height * 0.27)
      ..lineTo(width * 0.24, height * 0.37)
      ..lineTo(width * 0.18, height * 0.37)
      ..close()
      ..moveTo(width * 0.79, height * 0.27)
      ..lineTo(width * 0.76, height * 0.37)
      ..lineTo(width * 0.82, height * 0.37)
      ..close());
  }

  void _drawMuscle(Canvas canvas, String muscle, Path path) {
    final paint = Paint()
      ..color = _getColorForMuscle(muscle)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = _getColorForMuscle(muscle).withValues(alpha: 0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
