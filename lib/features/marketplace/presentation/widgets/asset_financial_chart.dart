import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/orion_theme.dart';

/// Detailed Financial Chart for Asset Detail Screen with X and Y axes,
/// Monotone Cubic Spline curve, red ambient fill, and touch-to-scrub crosshair.
class AssetFinancialChart extends StatefulWidget {
  const AssetFinancialChart({
    super.key,
    required this.points,
    required this.timeLabels,
    this.lineColor = OrionColors.red,
    this.height = 190,
    this.onScrub,
  });

  final List<double> points;
  final List<String> timeLabels;
  final Color lineColor;
  final double height;
  final ValueChanged<double?>? onScrub;

  @override
  State<AssetFinancialChart> createState() => _AssetFinancialChartState();
}

class _AssetFinancialChartState extends State<AssetFinancialChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  double? _scrubNormalizedX;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant AssetFinancialChart oldWidget) {
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
    super.dispose();
  }

  void _handleDrag(Offset localPosition, double chartWidth) {
    if (widget.points.length < 2) return;
    final clampedX = localPosition.dx.clamp(0.0, chartWidth);
    final normX = clampedX / chartWidth;

    final exactIndex = normX * (widget.points.length - 1);
    final i0 = exactIndex.floor().clamp(0, widget.points.length - 1);
    final i1 = exactIndex.ceil().clamp(0, widget.points.length - 1);
    final t = exactIndex - i0;

    final interpolatedValue =
        (widget.points[i0] * (1 - t)) + (widget.points[i1] * t);

    setState(() => _scrubNormalizedX = normX);
    widget.onScrub?.call(interpolatedValue);
  }

  void _handleDragEnd() {
    setState(() => _scrubNormalizedX = null);
    widget.onScrub?.call(null);
  }

  List<String> get _displayTimeLabels {
    final list = widget.timeLabels;
    if (list.isEmpty) return [];
    if (list.length <= 5) {
      return list.map(_formatTimeLabel).toList();
    }
    // Subsample evenly to exactly 5 labels: start, 25%, 50%, 75%, end
    const targetCount = 5;
    final result = <String>[];
    for (int i = 0; i < targetCount; i++) {
      final idx = ((i * (list.length - 1)) / (targetCount - 1)).round();
      result.add(_formatTimeLabel(list[idx]));
    }
    return result;
  }

  String _formatTimeLabel(String raw) {
    if (raw.contains('T') || raw.contains(' ')) {
      try {
        final dt = DateTime.parse(raw.replaceAll(' ', 'T'));
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m';
      } catch (_) {}
    }
    if (raw.length > 5 && raw.contains(':')) {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
    }
    return raw.length > 5 ? raw.substring(0, 5) : raw;
  }

  String _formatPrice(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final minVal = points.isNotEmpty ? points.reduce(math.min) : 0.0;
    final maxVal = points.isNotEmpty ? points.reduce(math.max) : 1.0;
    final diff = maxVal - minVal;

    // Generate 4 Y-axis price labels (from top to bottom)
    final yLabels = [
      _formatPrice(maxVal + diff * 0.08),
      _formatPrice(minVal + diff * 0.66),
      _formatPrice(minVal + diff * 0.33),
      _formatPrice(minVal - diff * 0.04),
    ];

    final timeLabels = _displayTimeLabels;

    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          // Main Chart Canvas with Right Y-Axis
          Expanded(
            child: Row(
              children: [
                // Chart drawing area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final chartWidth = constraints.maxWidth;
                      return GestureDetector(
                        onHorizontalDragDown: (details) =>
                            _handleDrag(details.localPosition, chartWidth),
                        onHorizontalDragUpdate: (details) =>
                            _handleDrag(details.localPosition, chartWidth),
                        onHorizontalDragEnd: (_) => _handleDragEnd(),
                        onHorizontalDragCancel: () => _handleDragEnd(),
                        onTapDown: (details) =>
                            _handleDrag(details.localPosition, chartWidth),
                        onTapUp: (_) => _handleDragEnd(),
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(chartWidth, double.infinity),
                              painter: _DetailedChartPainter(
                                points: widget.points,
                                progress: _animation.value,
                                lineColor: widget.lineColor,
                                scrubNormalizedX: _scrubNormalizedX,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Y-Axis Labels Column on the right
                SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yLabels.map((lbl) {
                      return Text(
                        lbl,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          if (timeLabels.isNotEmpty) ...[
            const SizedBox(height: 8),

            // X-Axis Time Labels Row
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: timeLabels.map((lbl) {
                      return Text(
                        lbl,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 48), // Align with Y-axis column
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailedChartPainter extends CustomPainter {
  _DetailedChartPainter({
    required this.points,
    required this.progress,
    required this.lineColor,
    this.scrubNormalizedX,
  });

  final List<double> points;
  final double progress;
  final Color lineColor;
  final double? scrubNormalizedX;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minVal = points.reduce(math.min);
    final maxVal = points.reduce(math.max);
    final valRange = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    const topPad = 8.0;
    const bottomPad = 6.0;
    final availableH = size.height - topPad - bottomPad;

    final n = points.length;
    final stepX = size.width / (n - 1);
    final List<Offset> coords = List.generate(n, (i) {
      final normY = (points[i] - minVal) / valRange;
      final y = size.height - bottomPad - (normY * availableH);
      return Offset(i * stepX, y);
    });

    final path = _computeMonotonePath(coords);

    // Subtle horizontal gridlines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.8;
    for (var i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Clip according to animation progress
    final clipRect = Rect.fromLTWH(0, 0, size.width * progress, size.height);
    canvas.save();
    canvas.clipRect(clipRect);

    // 1. Ambient gradient area fill
    final fillPath = Path.from(path)
      ..lineTo(coords.last.dx, size.height)
      ..lineTo(coords.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.40),
          lineColor.withValues(alpha: 0.15),
          lineColor.withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.40, 0.80, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 2. Stroke glow
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawPath(path, glowPaint);

    // 3. Crisp stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // 4. Live Pulse Endpoint Dot
    if (progress > 0.95 && scrubNormalizedX == null) {
      final lastCoord = coords.last;
      final halo = Paint()
        ..color = lineColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastCoord, 6.0, halo);

      final core = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastCoord, 2.5, core);
    }

    // 5. Interactive Scrub Crosshair
    if (scrubNormalizedX != null) {
      final scrubX = scrubNormalizedX! * size.width;
      final exactIndex = scrubNormalizedX! * (n - 1);
      final i0 = exactIndex.floor().clamp(0, n - 1);
      final i1 = exactIndex.ceil().clamp(0, n - 1);
      final t = exactIndex - i0;
      final scrubY = (coords[i0].dy * (1 - t)) + (coords[i1].dy * t);

      // Vertical guide line
      final vLinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(scrubX, 0), Offset(scrubX, size.height), vLinePaint);

      // Cursor dot
      final cHalo = Paint()
        ..color = lineColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(scrubX, scrubY), 6.5, cHalo);

      final cCore = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(scrubX, scrubY), 3.0, cCore);
    }

    canvas.restore();
  }

  Path _computeMonotonePath(List<Offset> pts) {
    final path = Path();
    final n = pts.length;
    if (n < 2) return path;

    path.moveTo(pts[0].dx, pts[0].dy);
    if (n == 2) {
      path.lineTo(pts[1].dx, pts[1].dy);
      return path;
    }

    final List<double> dx = List.filled(n - 1, 0.0);
    final List<double> m = List.filled(n - 1, 0.0);
    for (var i = 0; i < n - 1; i++) {
      dx[i] = pts[i + 1].dx - pts[i].dx;
      m[i] = (pts[i + 1].dy - pts[i].dy) / (dx[i] == 0 ? 1.0 : dx[i]);
    }

    final List<double> tangents = List.filled(n, 0.0);
    tangents[0] = m[0];
    tangents[n - 1] = m[n - 2];

    for (var i = 1; i < n - 1; i++) {
      if (m[i - 1] * m[i] <= 0) {
        tangents[i] = 0.0;
      } else {
        tangents[i] = (m[i - 1] + m[i]) / 2.0;
      }
    }

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
  bool shouldRepaint(covariant _DetailedChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.scrubNormalizedX != scrubNormalizedX;
  }
}
