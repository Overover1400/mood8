import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/analytics_models.dart';
import '../../theme/app_theme.dart';

enum _Line { mood, energy, focus }

class LineChartCard extends StatefulWidget {
  const LineChartCard({super.key, required this.series});
  final List<DataPoint> series;

  @override
  State<LineChartCard> createState() => _LineChartCardState();
}

class _LineChartCardState extends State<LineChartCard> {
  final Set<_Line> _visible = {_Line.mood, _Line.energy, _Line.focus};

  Color _colorOf(_Line l) {
    switch (l) {
      case _Line.mood:
        return AppColors.purple;
      case _Line.energy:
        return AppColors.pink;
      case _Line.focus:
        return AppColors.blueAccent;
    }
  }

  String _labelOf(_Line l) {
    switch (l) {
      case _Line.mood:
        return 'Mood';
      case _Line.energy:
        return 'Energy';
      case _Line.focus:
        return 'Focus';
    }
  }

  double? _valueOf(_Line l, DataPoint d) {
    switch (l) {
      case _Line.mood:
        return d.mood;
      case _Line.energy:
        return d.energy;
      case _Line.focus:
        return d.focus;
    }
  }

  List<FlSpot> _spots(_Line l) {
    final out = <FlSpot>[];
    for (var i = 0; i < widget.series.length; i++) {
      final v = _valueOf(l, widget.series[i]);
      if (v != null) out.add(FlSpot(i.toDouble(), v));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = widget.series.any((d) => d.hasData);
    if (!hasAny) {
      return _EmptyCard();
    }

    final chart = LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        minX: 0,
        maxX: (widget.series.length - 1).clamp(1, 365).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2.5,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.purple.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.bgCard.withValues(alpha: 0.95),
            tooltipBorder: BorderSide(
              color: AppColors.purple.withValues(alpha: 0.30),
            ),
            tooltipRoundedRadius: 12,
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.x.toInt().clamp(0, widget.series.length - 1);
              final date = widget.series[i].date;
              return LineTooltipItem(
                '${DateFormat('MMM d').format(date)}\n'
                '${s.bar.gradient != null ? "" : ""}'
                '${s.y.toStringAsFixed(1)}',
                TextStyle(
                  color: s.bar.color ?? Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.3,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          for (final l in _Line.values)
            if (_visible.contains(l) && _spots(l).isNotEmpty)
              LineChartBarData(
                spots: _spots(l),
                isCurved: true,
                curveSmoothness: 0.30,
                color: _colorOf(l),
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _colorOf(l).withValues(alpha: 0.20),
                      _colorOf(l).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 220, child: chart),
        const SizedBox(height: 12),
        _Legend(
          visible: _visible,
          onToggle: (l) {
            setState(() {
              if (_visible.contains(l)) {
                if (_visible.length > 1) _visible.remove(l);
              } else {
                _visible.add(l);
              }
            });
          },
          colorOf: _colorOf,
          labelOf: _labelOf,
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.visible,
    required this.onToggle,
    required this.colorOf,
    required this.labelOf,
  });

  final Set<_Line> visible;
  final ValueChanged<_Line> onToggle;
  final Color Function(_Line) colorOf;
  final String Function(_Line) labelOf;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final l in _Line.values) ...[
          GestureDetector(
            onTap: () => onToggle(l),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: visible.contains(l)
                        ? colorOf(l)
                        : colorOf(l).withValues(alpha: 0.25),
                    boxShadow: visible.contains(l)
                        ? [
                            BoxShadow(
                              color: colorOf(l).withValues(alpha: 0.55),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  labelOf(l),
                  style: TextStyle(
                    color: visible.contains(l)
                        ? AppColors.inkSoft
                        : AppColors.inkDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (l != _Line.focus) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        'Track for a few days to see your trends.',
        style: TextStyle(color: AppColors.inkDim, fontSize: 13),
      ),
    );
  }
}
