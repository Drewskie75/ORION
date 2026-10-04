import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/orion_theme.dart';

/// Authentic, Apple Stocks-grade Financial Area Chart.
/// Employs Monotone Cubic Spline (Fritsch-Carlson algorithm) to prevent
/// artificial squiggles/overshoots and create genuine market momentum.
/// Features a live glowing endpoint indicator and touch-to-scrub interactivity.
class PortfolioAreaChart extends StatefulWidget {
  const PortfolioAreaChart({
    super.key,
    required this.points,
    this.lineColor = OrionColors.red,
    this.height = 115,
    this.onScrub,
    this.enableScrubbing = true,
  });

  final List<double> points;
  final Color lineColor;
  final double height;
  final ValueChanged<double?>? onScrub;
  final bool enableScrubbing;

  @override
  State<PortfolioAreaChart> createState() => _PortfolioAreaChartState();
}

class _PortfolioAreaChartState extends State<PortfolioAreaChart>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _curveAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  double? _scrubNormalizedX;

  @override
  void initState() {
    super.initState();
    // Entrance reveal animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _curveAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();

    // Breathing pulse for the live endpoint dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.35, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant PortfolioAreaChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _animController.reset();
      _animController.forward();
      _scrubNormalizedX = null;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleDrag(Offset localPosition, double width) {
    if (!widget.enableScrubbing || widget.points.length < 2) return;
    final clampedX = localPosition.dx.clamp(0.0, width);
    final normX = clampedX / width;

    // Calculate interpolated price at scrub position
    final exactIndex = normX * (widget.points.length - 1);
    final i0 = exactIndex.floor().clamp(0, widget.points.length - 1);
    final i1 = exactIndex.ceil().clamp(0, widget.points.length - 1);
    final t = exactIndex - i0;

    final interpolatedValue = (widget.points[i0] * (1 - t)) + (widget.points[i1] * t);

    setState(() {
      _scrubNormalizedX = normX;
    });
    widget.onScrub?.call(interpolatedValue);
  }

  void _handleDragEnd() {
    if (!widget.enableScrubbing) return;
    setState(() {
      _scrubNormalizedX = null;
    });
    widget.onScrub?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragDown: (details) =>
              _handleDrag(details.localPosition, width),
          onHorizontalDragUpdate: (details) =>
              _handleDrag(details.localPosition, width),
          onHorizontalDragEnd: (_) => _handleDragEnd(),
          onHorizontalDragCancel: () => _handleDragEnd(),
          onTapDown: (details) => _handleDrag(details.localPosition, width),
          onTapUp: (_) => _handleDragEnd(),
          child: AnimatedBuilder(
            animation: Listenable.merge([_curveAnimation, _pulseAnimation]),
            builder: (context, child) {
              return CustomPaint(
                size: Size(width, widget.height),
                painter: _AppleStyleChartPainter(
                  points: widget.points,
                  progress: _curveAnimation.value,
                  lineColor: widget.lineColor,
                  pulseOpacity: _pulseAnimation.value,
                  scrubNormalizedX: _scrubNormalizedX,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AppleStyleChartPainter extends CustomPainter {
  _AppleStyleChartPainter({
    required this.points,
    required this.progress,
    required this.lineColor,
    required this.pulseOpacity,
    this.scrubNormalizedX,
  });

  final List<double> points;
  final double progress;
  final Color lineColor;
  final double pulseOpacity;
  final double? scrubNormalizedX;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minVal = points.reduce(math.min);
    final maxVal = points.reduce(math.max);
    final valRange = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    // Apple-style breathing room
    const topPad = 8.0;
    const bottomPad = 6.0;
    const rightPad = 7.0; // Margin so live pulsing dot is never clipped
    const leftPad = 2.0;
    final availableH = size.height - topPad - bottomPad;
    final availableW = size.width - leftPad - rightPad;

    // Convert data points to canvas coordinates
    final n = points.length;
    final stepX = availableW / (n - 1);
    final List<Offset> coords = List.generate(n, (i) {
      final normY = (points[i] - minVal) / valRange;
      final y = size.height - bottomPad - (normY * availableH);
      return Offset(leftPad + (i * stepX), y);
    });

    // Compute Monotone Cubic Spline (Fritsch-Carlson algorithm)
    final path = _computeMonotoneCubicPath(coords);

    // Apply animation reveal progress
    final clipRect = Rect.fromLTWH(0, 0, size.width * progress, size.height);
    canvas.save();
    canvas.clipRect(clipRect);

    // 1. Apple-style ambient gradient fill
    final fillPath = Path.from(path)
      ..lineTo(coords.last.dx, size.height)
      ..lineTo(coords.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.38),
          lineColor.withValues(alpha: 0.12),
          lineColor.withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.40, 0.80, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 2. Micro ambient glow along the stroke
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    canvas.drawPath(path, glowPaint);

    // 3. Crisp Apple-grade monoline stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // 4. Live Endpoint Pulse Dot (Apple Stocks style)
    if (progress > 0.95 && scrubNormalizedX == null) {
      final lastCoord = coords.last;

      // Outer pulsating halo ring
      final haloPaint = Paint()
        ..color = lineColor.withValues(alpha: pulseOpacity * 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastCoord, 6.5, haloPaint);

      // Core glow
      final coreGlow = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastCoord, 3.2, coreGlow);

      // Center bright specular dot
      final centerDot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastCoord, 1.8, centerDot);
    }

    // 5. Interactive Scrub Crosshair & Cursor
    if (scrubNormalizedX != null) {
      final scrubX = scrubNormalizedX! * size.width;

      // Find Y position along the curve
      final exactIndex = scrubNormalizedX! * (n - 1);
      final i0 = exactIndex.floor().clamp(0, n - 1);
      final i1 = exactIndex.ceil().clamp(0, n - 1);
      final t = exactIndex - i0;
      final scrubY = (coords[i0].dy * (1 - t)) + (coords[i1].dy * t);
      final scrubPoint = Offset(scrubX, scrubY);

      // Vertical guideline
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(scrubX, 0),
        Offset(scrubX, size.height),
        linePaint,
      );

      // Scrub indicator dot
      final cursorHalo = Paint()
        ..color = lineColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(scrubPoint, 6.0, cursorHalo);

      final cursorWhite = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(scrubPoint, 3.0, cursorWhite);
    }

    canvas.restore();
  }

  /// Fritsch-Carlson Monotone Cubic Spline generator
  Path _computeMonotoneCubicPath(List<Offset> pts) {
    final path = Path();
    final n = pts.length;
    if (n < 2) return path;

    path.moveTo(pts[0].dx, pts[0].dy);
    if (n == 2) {
      path.lineTo(pts[1].dx, pts[1].dy);
      return path;
    }

    // Calculate secant slopes
    final List<double> dx = List.filled(n - 1, 0.0);
    final List<double> m = List.filled(n - 1, 0.0);
    for (var i = 0; i < n - 1; i++) {
      dx[i] = pts[i + 1].dx - pts[i].dx;
      m[i] = (pts[i + 1].dy - pts[i].dy) / (dx[i] == 0 ? 1.0 : dx[i]);
    }

    // Calculate initial tangents
    final List<double> tangents = List.filled(n, 0.0);
    tangents[0] = m[0];
    tangents[n - 1] = m[n - 2];

    for (var i = 1; i < n - 1; i++) {
      if (m[i - 1] * m[i] <= 0) {
        // Local extrema: tangent must be horizontal (no overshoot)
        tangents[i] = 0.0;
      } else {
        tangents[i] = (m[i - 1] + m[i]) / 2.0;
      }
    }

    // Fritsch-Carlson monotonicity check
    for (var i = 0; i < n - 1; i++) {
      if (m[i] == 0) {
        tangents[i] = 0.0;
        tangents[i + 1] = 0.0;
      } else {
        final alpha = tangents[i] / m[i];
        final beta = tangents[i + 1] / m[i];
        final dist = (alpha * alpha) + (beta * beta);
        if (dist > 9.0) {
          final tau = 3.0 / math.sqrt(dist);
          tangents[i] = tau * alpha * m[i];
          tangents[i + 1] = tau * beta * m[i];
        }
      }
    }

    // Build smooth cubic Bezier path with calculated tangents
    for (var i = 0; i < n - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final deltaX = dx[i] / 3.0;

      final cp1 = Offset(p0.dx + deltaX, p0.dy + (tangents[i] * deltaX));
      final cp2 = Offset(p1.dx - deltaX, p1.dy - (tangents[i + 1] * deltaX));

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _AppleStyleChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.pulseOpacity != pulseOpacity ||
        oldDelegate.scrubNormalizedX != scrubNormalizedX;
  }
}

/// Mini Sparkline for Trending Asset row items with Monotone Spline
class MiniSparkline extends StatelessWidget {
  const MiniSparkline({
    super.key,
    required this.points,
    this.lineColor = OrionColors.red,
    this.width = 58,
    this.height = 24,
  });

  final List<double> points;
  final Color lineColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MiniSparklinePainter(
          points: points,
          lineColor: lineColor,
        ),
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  _MiniSparklinePainter({
    required this.points,
    required this.lineColor,
  });

  final List<double> points;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minVal = points.reduce(math.min);
    final maxVal = points.reduce(math.max);
    final valRange = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    const pad = 2.5;
    final availableHeight = size.height - (pad * 2);
    final n = points.length;
    final stepX = size.width / (n - 1);

    final List<Offset> coords = List.generate(n, (i) {
      final normY = (points[i] - minVal) / valRange;
      final y = size.height - pad - (normY * availableHeight);
      return Offset(i * stepX, y);
    });

    final path = Path()..moveTo(coords[0].dx, coords[0].dy);
    for (var i = 0; i < n - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // Area fill
    final fillPath = Path.from(path)
      ..lineTo(coords.last.dx, size.height)
      ..lineTo(coords.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.28),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
