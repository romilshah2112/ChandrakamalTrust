import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_record_detail_model.dart';

// ─── Page ─────────────────────────────────────────────────────────────────────

class PatientAnalyticsPage extends StatefulWidget {
  const PatientAnalyticsPage({
    super.key,
    required this.patientDataId,
    required this.patientName,
    this.patientGender = '',
    this.patientMobile = '',
    this.patientCity = '',
    this.patientBirthDate = '',
    this.readOnly = false,
  });

  final int patientDataId;
  final String patientName;
  final String patientGender;
  final String patientMobile;
  final String patientCity;
  final String patientBirthDate;
  /// When [readOnly] is true the page loads data via the patient self-access
  /// endpoint (`/me/analytics`) instead of the staff endpoint.
  final bool readOnly;

  @override
  State<PatientAnalyticsPage> createState() => _PatientAnalyticsPageState();
}

class _PatientAnalyticsPageState extends State<PatientAnalyticsPage>
    with SingleTickerProviderStateMixin {
  final _repo = PatientRepository();

  bool _loading = true;
  String? _error;
  bool _exportingPdf = false;

  List<String> _parameterNames = [];
  Map<String, Map<String, List<PatientRecordDetailModel>>> _byParameter = {};
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Session expired. Please log in again.';
      });
      return;
    }

    try {
      final details = widget.readOnly
          ? await _repo.getMyAnalytics(accessToken: token)
          : await _repo.getPatientAnalytics(
              accessToken: token,
              patientDataId: widget.patientDataId,
            );

      final byParameter = <String, Map<String, List<PatientRecordDetailModel>>>{};
      for (final d in details) {
        final paramName =
            d.recordParameterName.isNotEmpty ? d.recordParameterName : 'Other';
        byParameter
            .putIfAbsent(paramName, () => {})
            .putIfAbsent(d.keyword, () => [])
            .add(d);
      }

      final parameterNames = byParameter.keys.toList();
      _tabController?.dispose();
      final tabController = parameterNames.isEmpty
          ? null
          : TabController(length: parameterNames.length, vsync: this);

      setState(() {
        _byParameter = byParameter;
        _parameterNames = parameterNames;
        _tabController = tabController;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ── PDF export ────────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final now = DateTime.now();
    final generatedAt =
        '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (ctx) => ctx.pageNumber == 1
            ? _pdfPatientHeader(generatedAt)
            : _pdfRunningHeader(),
        build: (_) => _pdfBody(),
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfPatientHeader(String generatedAt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue900,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Patient Medical Records Report',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfInfoCell('Patient', widget.patientName),
                  pw.SizedBox(width: 20),
                  if (widget.patientGender.isNotEmpty)
                    _pdfInfoCell('Gender', widget.patientGender),
                  pw.SizedBox(width: 20),
                  if (widget.patientCity.isNotEmpty)
                    _pdfInfoCell('City', widget.patientCity),
                  pw.Spacer(),
                  _pdfInfoCell('Generated', generatedAt),
                ],
              ),
              if (widget.patientBirthDate.isNotEmpty ||
                  (widget.patientMobile.isNotEmpty &&
                      widget.patientMobile != '0')) ...[
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    if (widget.patientBirthDate.isNotEmpty)
                      _pdfInfoCell('Date of Birth', widget.patientBirthDate),
                    pw.SizedBox(width: 20),
                    if (widget.patientMobile.isNotEmpty &&
                        widget.patientMobile != '0')
                      _pdfInfoCell('Mobile', widget.patientMobile),
                  ],
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 18),
      ],
    );
  }

  pw.Widget _pdfRunningHeader() {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Patient Analytics — ${widget.patientName}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _pdfInfoCell(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blue200)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white)),
      ],
    );
  }

  List<pw.Widget> _pdfBody() {
    final widgets = <pw.Widget>[];
    for (final paramName in _parameterNames) {
      final keywordMap = _byParameter[paramName]!;

      widgets.add(
        pw.Container(
          width: double.infinity,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            paramName,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 10));

      for (final keyword in keywordMap.keys) {
        final rows = keywordMap[keyword]!;
        final points = <_DataPoint>[];
        for (final row in rows) {
          final d = DateTime.tryParse(row.reportDateTime);
          if (d != null) points.add(_DataPoint(date: d, row: row));
        }
        points.sort((a, b) => a.date.compareTo(b.date));
        if (points.isEmpty) continue;

        widgets.add(_pdfKeywordSection(
          keyword,
          rows.first.description,
          points,
          rows.first.idealLower,
          rows.first.idealUpper,
        ));
        widgets.add(pw.SizedBox(height: 14));
      }
      widgets.add(pw.SizedBox(height: 6));
    }
    return widgets;
  }

  pw.Widget _pdfKeywordSection(
    String keyword,
    String description,
    List<_DataPoint> points,
    double? idealLower,
    double? idealUpper,
  ) {
    final idealText = (idealLower != null || idealUpper != null)
        ? 'Ideal: ${idealLower?.toStringAsFixed(1) ?? '–'} – ${idealUpper?.toStringAsFixed(1) ?? '–'}'
        : '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Keyword heading
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(keyword,
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                if (description.isNotEmpty)
                  pw.Text(description,
                      style: pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            if (idealText.isNotEmpty)
              pw.Text(idealText,
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.green800)),
          ],
        ),
        pw.SizedBox(height: 8),

        // Mini bar chart — widget-based vertical bars (reliable across all page sizes)
        _buildPdfBarChart(points, idealLower, idealUpper),
        pw.SizedBox(height: 6),

        // Data table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey50),
              children: [
                _pdfCell('Date', header: true),
                _pdfCell('Value', header: true),
                _pdfCell('Status', header: true),
              ],
            ),
            ...points.map((p) {
              final val = p.row.readingValue;
              final ok = (idealLower == null || val >= idealLower) &&
                  (idealUpper == null || val <= idealUpper);
              return pw.TableRow(children: [
                _pdfCell(_fmtDate(p.date)),
                _pdfCell(val.toStringAsFixed(2)),
                _pdfCell(
                  ok ? 'Normal' : 'Review',
                  color: ok ? PdfColors.green700 : PdfColors.orange700,
                ),
              ]);
            }),
          ],
        ),
      ],
    );
  }

  /// Widget-based vertical bar chart for PDF.
  /// Uses [pw.Row] with [pw.Expanded] children so bars fill the full page
  /// width without needing [pw.CustomPaint] (which requires preferredSize).
  pw.Widget _buildPdfBarChart(
    List<_DataPoint> points,
    double? idealLower,
    double? idealUpper,
  ) {
    if (points.isEmpty) return pw.SizedBox();

    final values = points.map((p) => p.row.readingValue).toList();
    double minV = values.reduce(math.min);
    double maxV = values.reduce(math.max);
    if (idealLower != null) minV = math.min(minV, idealLower);
    if (idealUpper != null) maxV = math.max(maxV, idealUpper);
    final range = (maxV - minV).abs();
    final pad = range * 0.12 + 1;
    final effMin = minV - pad;
    final effMax = maxV + pad;
    final effRange = effMax - effMin;

    const chartH = 56.0; // points (≈ 2 cm)

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Bar area — bars grow upward via CrossAxisAlignment.end
        pw.SizedBox(
          height: chartH,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: points.map((p) {
              final val = p.row.readingValue;
              final normalized =
                  ((val - effMin) / effRange).clamp(0.0, 1.0);
              final barH = math.max(normalized * chartH, 2.0);
              final ok = (idealLower == null || val >= idealLower) &&
                  (idealUpper == null || val <= idealUpper);
              return pw.Expanded(
                child: pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 2),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        height: barH,
                        decoration: pw.BoxDecoration(
                          color: ok
                              ? PdfColors.blue600
                              : PdfColors.orange,
                          borderRadius: pw.BorderRadius.only(
                            topLeft: const pw.Radius.circular(2),
                            topRight: const pw.Radius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Baseline rule
        pw.Container(height: 0.6, color: PdfColors.blueGrey300),
        pw.SizedBox(height: 3),
        // X-axis date labels
        pw.Row(
          children: points.map((p) {
            return pw.Expanded(
              child: pw.Text(
                _fmtDate(p.date),
                style: pw.TextStyle(
                    fontSize: 6, color: PdfColors.blueGrey600),
                textAlign: pw.TextAlign.center,
              ),
            );
          }).toList(),
        ),
        // Ideal range legend
        if (idealLower != null || idealUpper != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Row(
              children: [
                pw.Container(
                    width: 10,
                    height: 1.5,
                    color: PdfColors.green700),
                pw.SizedBox(width: 4),
                pw.Text(
                  'Ideal: ${idealLower?.toStringAsFixed(1) ?? '–'} – ${idealUpper?.toStringAsFixed(1) ?? '–'}',
                  style: pw.TextStyle(
                      fontSize: 7, color: PdfColors.green800),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _pdfCell(String text,
      {bool header = false, PdfColor? color}) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: header ? 9 : 8,
          fontWeight:
              header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (header ? PdfColors.blueGrey800 : PdfColors.black),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tabController = _tabController;
    final showTabs =
        !_loading && _error == null && tabController != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics — ${widget.patientName}'),
        actions: [
          if (!_loading && _error == null && _parameterNames.isNotEmpty)
            _exportingPdf
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Export PDF',
                    onPressed: _exportPdf,
                  ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: showTabs
            ? TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _parameterNames
                    .map((n) => Tab(text: n))
                    .toList(),
              )
            : null,
      ),
      body: _buildBody(tabController),
    );
  }

  Widget _buildBody(TabController? tabController) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (tabController == null || _parameterNames.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No analytics data yet.\nSave extracted values from medical records to see charts here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: tabController,
      children: _parameterNames.map((paramName) {
        final keywordMap = _byParameter[paramName]!;
        return _ParameterTabContent(keywordMap: keywordMap);
      }).toList(),
    );
  }
}

// ─── Tab content ──────────────────────────────────────────────────────────────

class _ParameterTabContent extends StatelessWidget {
  const _ParameterTabContent({required this.keywordMap});

  final Map<String, List<PatientRecordDetailModel>> keywordMap;

  @override
  Widget build(BuildContext context) {
    final keywords = keywordMap.keys.toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: keywords.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final keyword = keywords[index];
        final rows = keywordMap[keyword]!;
        // Alternate: even indices → 3D bar chart, odd → line chart.
        return index.isEven
            ? _ThreeDBarChartCard(keyword: keyword, rows: rows)
            : _KeywordChartCard(keyword: keyword, rows: rows);
      },
    );
  }
}

// ─── 3D bar chart card ────────────────────────────────────────────────────────

class _ThreeDBarChartCard extends StatelessWidget {
  const _ThreeDBarChartCard({required this.keyword, required this.rows});

  final String keyword;
  final List<PatientRecordDetailModel> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final points = <_DataPoint>[];
    for (final row in rows) {
      final date = DateTime.tryParse(row.reportDateTime);
      if (date != null) points.add(_DataPoint(date: date, row: row));
    }
    if (points.isEmpty) return const SizedBox.shrink();
    points.sort((a, b) => a.date.compareTo(b.date));

    final idealLower = rows.first.idealLower;
    final idealUpper = rows.first.idealUpper;
    final description = rows.first.description;

    final latest = points.last.row.readingValue;
    final latestOk = (idealLower == null || latest >= idealLower) &&
        (idealUpper == null || latest <= idealUpper);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keyword,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: Icon(
                  latestOk
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  size: 16,
                  color: latestOk ? Colors.green : Colors.orange,
                ),
                label: Text(
                  'Latest: ${latest.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: latestOk ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: (latestOk ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.1),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ]),

            // ── Ideal range label ────────────────────────────────────
            if (idealLower != null || idealUpper != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Ideal range: ${idealLower?.toStringAsFixed(1) ?? '–'} – ${idealUpper?.toStringAsFixed(1) ?? '–'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                      ),
                ),
              )
            else
              const SizedBox(height: 8),

            // ── 3D Bar Chart ─────────────────────────────────────────
            SizedBox(
              height: 240,
              child: CustomPaint(
                painter: _ThreeDBarPainter(
                  points: points,
                  color: colorScheme.primary,
                  idealLower: idealLower,
                  idealUpper: idealUpper,
                ),
                size: Size.infinite,
              ),
            ),

            // ── Data table (collapsible) ─────────────────────────────
            const SizedBox(height: 4),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                title: const Text(
                  'View Data',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: false,
                children: [
                  _buildDataTable(context, points, idealLower, idealUpper),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    List<_DataPoint> points,
    double? idealLower,
    double? idealUpper,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            color:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          children: [
            _th('Date'),
            _th('Value'),
            _th('Status'),
          ],
        ),
        ...points.map((p) {
          final val = p.row.readingValue;
          final ok = (idealLower == null || val >= idealLower) &&
              (idealUpper == null || val <= idealUpper);
          return TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color:
                      colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            children: [
              _td(_fmtDate(p.date)),
              _td(val.toStringAsFixed(2)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(children: [
                  Icon(
                    ok
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    size: 14,
                    color: ok ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(ok ? 'Normal' : 'Review',
                      style: TextStyle(
                        fontSize: 12,
                        color: ok ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      )),
                ]),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _th(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(t,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _td(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(t, style: const TextStyle(fontSize: 12)),
      );
}

// ─── 3D bar chart painter ─────────────────────────────────────────────────────

class _ThreeDBarPainter extends CustomPainter {
  const _ThreeDBarPainter({
    required this.points,
    required this.color,
    this.idealLower,
    this.idealUpper,
  });

  final List<_DataPoint> points;
  final Color color;
  final double? idealLower;
  final double? idealUpper;

  static const double _dx = 11; // depth offset right
  static const double _dy = 8; // depth offset up
  static const double _leftPad = 50; // Y-axis labels
  static const double _bottomPad = 38; // X-axis labels
  static const double _topPad = _dy + 6;
  static const double _rightPad = _dx + 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final values = points.map((p) => p.row.readingValue).toList();
    double minV = values.reduce(math.min);
    double maxV = values.reduce(math.max);
    if (idealLower != null) minV = math.min(minV, idealLower!);
    if (idealUpper != null) maxV = math.max(maxV, idealUpper!);
    final range = (maxV - minV).abs();
    final pad = range * 0.15 + 1;
    final effMin = minV - pad;
    final effMax = maxV + pad;
    final effRange = effMax - effMin;

    final chartL = _leftPad;
    final chartR = size.width - _rightPad;
    final chartT = _topPad;
    final chartB = size.height - _bottomPad;
    final chartW = chartR - chartL;
    final chartH = chartB - chartT;

    // Flutter top-down: value → Y (higher value = smaller Y = higher on screen)
    double toY(double v) => chartB - (v - effMin) / effRange * chartH;

    // ── Grid & Y-axis labels ──────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final v = effMin + effRange * i / 4;
      final y = toY(v);
      canvas.drawLine(
          Offset(chartL, y), Offset(chartR + _dx, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(1),
          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: _leftPad - 4);
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // ── Ideal range fill & dashed lines ──────────────────────────
    if (idealLower != null && idealUpper != null) {
      canvas.drawRect(
        Rect.fromLTRB(chartL, toY(idealUpper!), chartR, toY(idealLower!)),
        Paint()
          ..color = Colors.green.withValues(alpha: 0.09)
          ..style = PaintingStyle.fill,
      );
    }

    final dashPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    void dashedH(double yPos) {
      double x = chartL;
      bool on = true;
      while (x < chartR + _dx) {
        final end = math.min(x + (on ? 6 : 4), chartR + _dx);
        if (on) canvas.drawLine(Offset(x, yPos), Offset(end, yPos), dashPaint);
        x = end;
        on = !on;
      }
    }

    if (idealLower != null) dashedH(toY(idealLower!));
    if (idealUpper != null) dashedH(toY(idealUpper!));

    // ── Bars ─────────────────────────────────────────────────────
    final n = points.length;
    final slotW = chartW / n;
    final barW = (slotW * 0.58).clamp(10.0, 50.0);

    final frontColor = color;
    final topColor = Color.lerp(color, Colors.white, 0.40)!;
    final sideColor = Color.lerp(color, Colors.black, 0.30)!;
    final badFront = Colors.red.shade400;
    final badTop = Color.lerp(Colors.red.shade400, Colors.white, 0.38)!;
    final badSide = Color.lerp(Colors.red.shade400, Colors.black, 0.28)!;

    for (int i = 0; i < n; i++) {
      final value = points[i].row.readingValue;
      final bL = chartL + i * slotW + (slotW - barW) / 2;
      final bT = toY(value);
      final bB = chartB;
      final bR = bL + barW;

      final ok = (idealLower == null || value >= idealLower!) &&
          (idealUpper == null || value <= idealUpper!);
      final fc = ok ? frontColor : badFront;
      final tc = ok ? topColor : badTop;
      final sc = ok ? sideColor : badSide;

      // Right face (drawn behind front)
      final rightFace = Path()
        ..moveTo(bR, bT)
        ..lineTo(bR + _dx, bT - _dy)
        ..lineTo(bR + _dx, bB - _dy)
        ..lineTo(bR, bB)
        ..close();
      canvas.drawPath(rightFace, Paint()..color = sc);

      // Front face
      canvas.drawRect(Rect.fromLTRB(bL, bT, bR, bB), Paint()..color = fc);

      // Top face
      final topFace = Path()
        ..moveTo(bL, bT)
        ..lineTo(bL + _dx, bT - _dy)
        ..lineTo(bR + _dx, bT - _dy)
        ..lineTo(bR, bT)
        ..close();
      canvas.drawPath(topFace, Paint()..color = tc);

      // Subtle edge outline
      final edge = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke;
      canvas.drawRect(Rect.fromLTRB(bL, bT, bR, bB), edge);
      canvas.drawPath(topFace, edge);
      canvas.drawPath(rightFace, edge);

      // Value label inside bar (if tall enough)
      if (bB - bT > 18) {
        final vTp = TextPainter(
          text: TextSpan(
            text: value.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 8,
                color: Colors.white,
                fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        );
        vTp.layout();
        vTp.paint(
            canvas, Offset(bL + (barW - vTp.width) / 2, bT + 4));
      }

      // X-axis date label
      final dt = points[i].date;
      final lbl = _fmtDate(dt);
      final dTp = TextPainter(
        text: TextSpan(
          text: lbl,
          style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      dTp.layout(maxWidth: slotW + _dx);
      dTp.paint(
          canvas,
          Offset(
            bL + barW / 2 - dTp.width / 2 + _dx / 2,
            chartB + 4,
          ));
    }

    // ── Bottom axis line ─────────────────────────────────────────
    canvas.drawLine(
      Offset(chartL, chartB),
      Offset(chartR, chartB),
      Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ThreeDBarPainter old) =>
      old.points != points ||
      old.color != color ||
      old.idealLower != idealLower ||
      old.idealUpper != idealUpper;
}

// ─── PDF bar chart painter (top-level function — pw.CustomPainter is a typedef)─

// ─── Line chart card ──────────────────────────────────────────────────────────

class _KeywordChartCard extends StatefulWidget {
  const _KeywordChartCard({required this.keyword, required this.rows});

  final String keyword;
  final List<PatientRecordDetailModel> rows;

  @override
  State<_KeywordChartCard> createState() => _KeywordChartCardState();
}

class _KeywordChartCardState extends State<_KeywordChartCard> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final colorScheme = Theme.of(context).colorScheme;

    final points = <_DataPoint>[];
    for (final row in rows) {
      final date = DateTime.tryParse(row.reportDateTime);
      if (date != null) points.add(_DataPoint(date: date, row: row));
    }
    if (points.isEmpty) return const SizedBox.shrink();
    points.sort((a, b) => a.date.compareTo(b.date));

    final idealLower = rows.first.idealLower;
    final idealUpper = rows.first.idealUpper;
    final description = rows.first.description;

    double minY = points.map((p) => p.row.readingValue).reduce(math.min);
    double maxY = points.map((p) => p.row.readingValue).reduce(math.max);
    if (idealLower != null) minY = math.min(minY, idealLower);
    if (idealUpper != null) maxY = math.max(maxY, idealUpper);
    final yPadding = (maxY - minY) * 0.15;
    final chartMinY = minY - yPadding - 1;
    final chartMaxY = maxY + yPadding + 1;

    final epoch = points.first.date;
    double toDays(DateTime dt) => dt.difference(epoch).inMinutes / 1440.0;

    final spots = points
        .map((p) => FlSpot(toDays(p.date), p.row.readingValue))
        .toList();
    final chartMinX = spots.first.x - 0.5;
    final chartMaxX = spots.last.x + 0.5;

    Color dotColor(double value) {
      if (idealLower != null && value < idealLower) return Colors.red;
      if (idealUpper != null && value > idealUpper) return Colors.red;
      return colorScheme.primary;
    }

    final latest = points.last.row.readingValue;
    final latestOk = (idealLower == null || latest >= idealLower) &&
        (idealUpper == null || latest <= idealUpper);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.keyword,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (description.isNotEmpty)
                      Text(description,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: Icon(
                  latestOk
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  size: 16,
                  color: latestOk ? Colors.green : Colors.orange,
                ),
                label: Text(
                  'Latest: ${latest.toStringAsFixed(1)}',
                  style: TextStyle(
                      color: latestOk ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600),
                ),
                backgroundColor:
                    (latestOk ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.1),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ]),
            if (idealLower != null || idealUpper != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Ideal range: ${idealLower?.toStringAsFixed(1) ?? '–'} – ${idealUpper?.toStringAsFixed(1) ?? '–'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.green.shade700),
                ),
              )
            else
              const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: chartMinX,
                  maxX: chartMaxX,
                  minY: chartMinY,
                  maxY: chartMaxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (chartMaxY - chartMinY) / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                          color: colorScheme.outline
                              .withValues(alpha: 0.4)),
                      left: BorderSide(
                          color: colorScheme.outline
                              .withValues(alpha: 0.4)),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: (chartMaxX - chartMinX) /
                            (points.length > 1
                                ? (points.length - 1).toDouble()
                                : 1),
                        getTitlesWidget: (value, meta) {
                          final dt = epoch.add(Duration(
                              minutes: (value * 1440).round()));
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              _fmtDate(dt),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontSize: 9),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min || value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(value.toStringAsFixed(1),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall),
                          );
                        },
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (idealLower != null)
                        HorizontalLine(
                          y: idealLower,
                          color:
                              Colors.green.withValues(alpha: 0.8),
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(
                                right: 4, bottom: 2),
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                            labelResolver: (_) => 'Min',
                          ),
                        ),
                      if (idealUpper != null)
                        HorizontalLine(
                          y: idealUpper,
                          color:
                              Colors.green.withValues(alpha: 0.8),
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.bottomRight,
                            padding: const EdgeInsets.only(
                                right: 4, top: 2),
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                            labelResolver: (_) => 'Max',
                          ),
                        ),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    touchCallback: (event, response) {
                      final idx =
                          response?.lineBarSpots?.first.spotIndex;
                      if (mounted) setState(() => _touchedIndex = idx);
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          colorScheme.inverseSurface,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (spots) => spots.map((spot) {
                        final dt = epoch.add(Duration(
                            minutes: (spot.x * 1440).round()));
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(2)}\n${_fmtDate(dt)}',
                          TextStyle(
                            color: colorScheme.onInverseSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    if (idealLower != null && idealUpper != null) ...[
                      LineChartBarData(
                        spots: [
                          FlSpot(chartMinX, idealLower),
                          FlSpot(chartMaxX, idealLower)
                        ],
                        isCurved: false,
                        color: Colors.transparent,
                        barWidth: 0,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: [
                          FlSpot(chartMinX, idealUpper),
                          FlSpot(chartMaxX, idealUpper)
                        ],
                        isCurved: false,
                        color: Colors.transparent,
                        barWidth: 0,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                    LineChartBarData(
                      spots: spots,
                      isCurved: points.length > 2,
                      curveSmoothness: 0.3,
                      color: colorScheme.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final value =
                              points[index].row.readingValue;
                          final isTouched = index == _touchedIndex;
                          return FlDotCirclePainter(
                            radius: isTouched ? 7 : 4,
                            color: dotColor(value),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color:
                            colorScheme.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                  betweenBarsData:
                      idealLower != null && idealUpper != null
                          ? [
                              BetweenBarsData(
                                fromIndex: 0,
                                toIndex: 1,
                                color: Colors.green
                                    .withValues(alpha: 0.10),
                              )
                            ]
                          : [],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                title: const Text(
                  'View Data',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: false,
                children: [
                  _buildDataTable(context, points, idealLower, idealUpper),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    List<_DataPoint> points,
    double? idealLower,
    double? idealUpper,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          children: [
            _th('Date'),
            _th('Value'),
            _th('Status'),
          ],
        ),
        ...points.map((p) {
          final val = p.row.readingValue;
          final ok = (idealLower == null || val >= idealLower) &&
              (idealUpper == null || val <= idealUpper);
          return TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant
                      .withValues(alpha: 0.4),
                ),
              ),
            ),
            children: [
              _th2(_fmtDate(p.date)),
              _th2(val.toStringAsFixed(2)),
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 6, horizontal: 8),
                child: Row(children: [
                  Icon(
                    ok
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    size: 14,
                    color: ok ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(ok ? 'Normal' : 'Review',
                      style: TextStyle(
                        fontSize: 12,
                        color: ok ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      )),
                ]),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _th(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _th2(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(t, style: const TextStyle(fontSize: 12)),
      );
}

// ─── Helper ───────────────────────────────────────────────────────────────────

/// Formats a [DateTime] as `dd-MMM-yy` (e.g. `03-Apr-25`).
String _fmtDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = dt.day.toString().padLeft(2, '0');
  final m = months[dt.month - 1];
  final y = dt.year.toString().substring(2);
  return '$d-$m-$y';
}

class _DataPoint {
  const _DataPoint({required this.date, required this.row});
  final DateTime date;
  final PatientRecordDetailModel row;
}
