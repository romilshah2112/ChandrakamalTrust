import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/theme.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/staff_analytics/data/staff_analytics_repository.dart';
import 'package:optima_healthcare_mobile/features/staff_analytics/models/staff_dashboard_analytics_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  List<String> _referenceNames = const [];
  String? _selectedReferenceName;
  bool _exportingPdf = false;

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
      final results = await Future.wait<dynamic>([
        _repo.getReferenceNames(accessToken: token),
        _repo.getDashboardAnalytics(
          accessToken: token,
          referenceName: _selectedReferenceName,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _referenceNames = results[0] as List<String>;
        _analytics = results[1] as StaffDashboardAnalyticsModel;
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
      appBar: AppBar(
        title: const Text('Patient Analytics'),
        actions: [
          if (_exportingPdf)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            PopupMenuButton<_PdfAction>(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              enabled: analytics != null,
              onSelected: (action) async {
                switch (action) {
                  case _PdfAction.print:
                    await _printPdf();
                    break;
                  case _PdfAction.share:
                    await _sharePdf();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _PdfAction.print,
                  child: ListTile(
                    leading: Icon(Icons.print_outlined),
                    title: Text('Print'),
                  ),
                ),
                PopupMenuItem(
                  value: _PdfAction.share,
                  child: ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Share'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : analytics == null
          ? const Center(child: Text('No analytics available.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _referenceDropdown(),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: 'Patients by Gender',
                    child: _ThreeDPieChart(data: analytics.patientsByGender),
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

  Widget _referenceDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedReferenceName,
      decoration: InputDecoration(
        labelText: 'Reference Name',
        prefixIcon: const Icon(Icons.filter_alt_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All Health Camps'),
        ),
        ..._referenceNames.map(
          (name) => DropdownMenuItem<String?>(
            value: name,
            child: Text(name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedReferenceName = value;
          _loading = true;
          _error = null;
        });
        _load();
      },
    );
  }

  Future<void> _printPdf() async {
    await _runPdfAction(() async {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    });
  }

  Future<void> _sharePdf() async {
    await _runPdfAction(() async {
      final bytes = await _buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: _pdfFileName());
    });
  }

  Future<void> _runPdfAction(Future<void> Function() action) async {
    if (_exportingPdf || _analytics == null) return;
    setState(() => _exportingPdf = true);
    try {
      await action();
    } catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  Future<Uint8List> _buildPdf() async {
    final analytics = _analytics;
    if (analytics == null) {
      throw const FormatException('No analytics available to export.');
    }

    final generatedAt = _formatDateTime(DateTime.now());
    final referenceLabel = _selectedReferenceName ?? 'All Health Camps';
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _pdfHeader(referenceLabel, generatedAt),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          _pdfSummary(analytics),
          pw.SizedBox(height: 12),
          _pdfSection('Patients by Gender', analytics.patientsByGender),
          _pdfSection('Patients by Age', analytics.patientsByAgeGroup),
          _pdfSection(
            'Patients by BP Systolic',
            analytics.patientsByBPSystolicRange,
          ),
          _pdfSection(
            'Patients by BP Diastolic',
            analytics.patientsByBPDiastolicRange,
          ),
          _pdfSection(
            'Patients by Blood Sugar',
            analytics.patientsByBloodSugarRange,
          ),
          _pdfSection('Patients by City', analytics.patientsByCity),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfHeader(String referenceLabel, String generatedAt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: const pw.BoxDecoration(color: PdfColors.blue900),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Patient Analytics Report',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Reference: $referenceLabel',
                style: const pw.TextStyle(
                  color: PdfColors.blue100,
                  fontSize: 10,
                ),
              ),
              pw.Text(
                'Generated: $generatedAt',
                style: const pw.TextStyle(
                  color: PdfColors.blue100,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  pw.Widget _pdfSummary(StaffDashboardAnalyticsModel analytics) {
    final totalPatients = analytics.patientsByGender.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
      ),
      child: pw.Row(
        children: [
          _pdfSummaryCell('Total Patients', totalPatients.toStringAsFixed(0)),
          _pdfSummaryCell('Reference Type', 'Health Camp'),
          _pdfSummaryCell('Reference Name', _selectedReferenceName ?? 'All'),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSection(String title, List<StaffAnalyticsPointModel> data) {
    final visible = data.where((item) => item.value > 0).toList();
    final rows = visible.isEmpty ? data : visible;
    final max = rows.map((item) => item.value).fold<double>(0, math.max);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (rows.isEmpty)
            pw.Text(
              'No data available.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.blueGrey200,
                width: 0.5,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.2),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey50,
                  ),
                  children: [
                    _pdfCell('Label', header: true),
                    _pdfCell('Count', header: true),
                    _pdfCell('Distribution', header: true),
                  ],
                ),
                ...rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final ratio = max <= 0 ? 0.0 : (item.value / max);
                  final color =
                      _pdfChartPalette[index % _pdfChartPalette.length];
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Row(
                          children: [
                            pw.Container(width: 9, height: 9, color: color),
                            pw.SizedBox(width: 5),
                            pw.Expanded(
                              child: pw.Text(
                                item.label,
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _pdfCell(item.value.toStringAsFixed(0)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Container(
                          width: 160,
                          height: 8,
                          alignment: pw.Alignment.centerLeft,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          child: pw.Container(
                            width: 160 * ratio.clamp(0, 1),
                            height: 8,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: header ? 9 : 8,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.blueGrey800 : PdfColors.black,
        ),
      ),
    );
  }

  String _pdfFileName() {
    final reference = (_selectedReferenceName ?? 'all-health-camps')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'patient-analytics-${reference.isEmpty ? 'report' : reference}.pdf';
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day-$month-${value.year} $hour:$minute';
  }
}

enum _PdfAction { print, share }

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

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

      final rect = Rect.fromCircle(
        center: center.translate(0, depth),
        radius: radius,
      );
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
      final barHeight = maxValue <= 0
          ? 0.0
          : (item.value / maxValue) * (chartHeight - 24);
      final barRect = Rect.fromLTWH(
        x,
        chartHeight - barHeight,
        barWidth,
        barHeight,
      );
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

const _pdfChartPalette = [
  PdfColor.fromInt(0xFFCB4E42),
  PdfColor.fromInt(0xFF2A9D8F),
  PdfColor.fromInt(0xFFE9C46A),
  PdfColor.fromInt(0xFF457B9D),
  PdfColor.fromInt(0xFFF4A261),
  PdfColor.fromInt(0xFF6D597A),
];
