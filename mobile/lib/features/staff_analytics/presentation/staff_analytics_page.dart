import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/theme.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/staff_analytics/data/staff_analytics_repository.dart';
import 'package:optima_healthcare_mobile/features/staff_analytics/models/staff_dashboard_analytics_model.dart';

class StaffAnalyticsPage extends StatefulWidget {
  const StaffAnalyticsPage({super.key});

  @override
  State<StaffAnalyticsPage> createState() => _StaffAnalyticsPageState();
}

class _StaffAnalyticsPageState extends State<StaffAnalyticsPage> {
  final _repo = StaffAnalyticsRepository();

  bool _loading = true;
  String? _error;
  StaffDashboardAnalyticsModel? _analytics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Session expired. Please login again.';
      });
      return;
    }

    try {
      final analytics = await _repo.getDashboardAnalytics(accessToken: token);
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _loading = false;
        _error = null;
      });
    } catch (ex) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ex.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _analytics;
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : analytics == null
                  ? const Center(child: Text('No analytics available.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _ChartCard(
                            title: 'Patients by Gender',
                            child: _ThreeDPieChart(
                              data: analytics.patientsByGender,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ChartCard(
                            title: 'Patients by Age',
                            child: _ThreeDVerticalBarChart(
                              data: analytics.patientsByAgeGroup,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ChartCard(
                            title: 'Patients by BP Systolic',
                            child: _ThreeDVerticalBarChart(
                              data: analytics.patientsByBPSystolicRange,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ChartCard(
                            title: 'Patients by BP Diastolic',
                            child: _ThreeDVerticalBarChart(
                              data: analytics.patientsByBPDiastolicRange,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ChartCard(
                            title: 'Patients by Blood Sugar',
                            child: _ThreeDVerticalBarChart(
                              data: analytics.patientsByBloodSugarRange,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ChartCard(
                            title: 'Patients by City',
                            child: _HorizontalCountChart(
                              data: analytics.patientsByCity,
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ThreeDPieChart extends StatelessWidget {
  const _ThreeDPieChart({required this.data});

  final List<StaffAnalyticsPointModel> data;

  @override
  Widget build(BuildContext context) {
    final chartData = data.where((item) => item.value > 0).toList();
    if (chartData.isEmpty) {
      return const Text('No data available.');
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: CustomPaint(
            painter: _PiePainter(chartData),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: chartData.asMap().entries.map((entry) {
            final color = _chartPalette[entry.key % _chartPalette.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, color: color),
                const SizedBox(width: 6),
                Text(
                  '${entry.value.label} (${entry.value.value.toStringAsFixed(0)})',
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ThreeDVerticalBarChart extends StatelessWidget {
  const _ThreeDVerticalBarChart({required this.data});

  final List<StaffAnalyticsPointModel> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text('No data available.');
    }

    return SizedBox(
      height: 250,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final barWidth = width / (data.length * 1.6);
          final gap = barWidth * 0.6;
          final chartHeight = 220.0;

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _VerticalBarPainter(data),
                  child: const SizedBox.expand(),
                ),
              ),
              ...data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final left = (gap / 2) + index * (barWidth + gap);
                return Positioned(
                  left: left,
                  top: 0,
                  width: barWidth + 10,
                  height: chartHeight,
                  child: Tooltip(
                    message: '${item.label}: ${item.value.toStringAsFixed(0)}',
                    waitDuration: const Duration(milliseconds: 150),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _HorizontalCountChart extends StatelessWidget {
  const _HorizontalCountChart({required this.data});

  final List<StaffAnalyticsPointModel> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text('No data available.');
    }

    final max = data.map((item) => item.value).fold<double>(0, math.max);
    return Column(
      children: data.asMap().entries.map((entry) {
        final item = entry.value;
        final color = _chartPalette[entry.key % _chartPalette.length];
        final ratio = max <= 0 ? 0.0 : item.value / max;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Tooltip(
            message: '${item.label}: ${item.value.toStringAsFixed(0)}',
            waitDuration: const Duration(milliseconds: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(item.value.toStringAsFixed(0)),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Container(
                        width: constraints.maxWidth * ratio.clamp(0, 1),
                        height: 18,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.85), color],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.data);

  final List<StaffAnalyticsPointModel> data;

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2 - 8);
    final radius = math.min(size.width, size.height) * 0.28;
    final depth = 16.0;
    var startAngle = -math.pi / 2;

    for (var i = 0; i < data.length; i++) {
      final sweep = (data[i].value / total) * math.pi * 2;
      final color = _chartPalette[i % _chartPalette.length];

      final sidePaint = Paint()..color = color.withValues(alpha: 0.7);
      final topPaint = Paint()..color = color;

      final rect = Rect.fromCircle(center: center.translate(0, depth), radius: radius);
      canvas.drawArc(rect, startAngle, sweep, true, sidePaint);

      final topRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(topRect, startAngle, sweep, true, topPaint);

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _VerticalBarPainter extends CustomPainter {
  _VerticalBarPainter(this.data);

  final List<StaffAnalyticsPointModel> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxValue = data.map((item) => item.value).fold<double>(0, math.max);
    final chartHeight = size.height - 30;
    final barWidth = size.width / (data.length * 1.6);
    final gap = barWidth * 0.6;
    final floorPaint = Paint()..color = Colors.grey.shade300;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      floorPaint..strokeWidth = 2,
    );

    var x = gap / 2;
    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final color = _chartPalette[i % _chartPalette.length];
      final barHeight = maxValue <= 0 ? 0.0 : (item.value / maxValue) * (chartHeight - 24);
      final barRect = Rect.fromLTWH(x, chartHeight - barHeight, barWidth, barHeight);
      final frontPaint = Paint()..color = color;
      final sidePaint = Paint()..color = color.withValues(alpha: 0.75);
      final topPaint = Paint()..color = color.withValues(alpha: 0.9);

      canvas.drawRect(barRect, frontPaint);
      final sidePath = Path()
        ..moveTo(barRect.right, barRect.top)
        ..lineTo(barRect.right + 8, barRect.top - 6)
        ..lineTo(barRect.right + 8, barRect.bottom - 6)
        ..lineTo(barRect.right, barRect.bottom)
        ..close();
      canvas.drawPath(sidePath, sidePaint);

      final topPath = Path()
        ..moveTo(barRect.left, barRect.top)
        ..lineTo(barRect.left + 8, barRect.top - 6)
        ..lineTo(barRect.right + 8, barRect.top - 6)
        ..lineTo(barRect.right, barRect.top)
        ..close();
      canvas.drawPath(topPath, topPaint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: const TextStyle(color: AppTheme.brandCharcoal, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth + 12);
      labelPainter.paint(canvas, Offset(x - 2, chartHeight + 8));

      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

const _chartPalette = [
  Color(0xFFCB4E42),
  Color(0xFF2A9D8F),
  Color(0xFFE9C46A),
  Color(0xFF457B9D),
  Color(0xFFF4A261),
  Color(0xFF6D597A),
];

