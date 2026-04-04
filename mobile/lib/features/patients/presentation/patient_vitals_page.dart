import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_vitals_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_vitals_save_request.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PatientVitalsPage extends StatefulWidget {
  const PatientVitalsPage({
    super.key,
    required this.patientDataId,
    required this.patientName,
  });

  final int patientDataId;
  final String patientName;

  @override
  State<PatientVitalsPage> createState() => _PatientVitalsPageState();
}

class _PatientVitalsPageState extends State<PatientVitalsPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final _repo = PatientRepository();
  late final TabController _tabController;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<PatientVitalsModel> _vitals = const [];

  // Touched index for the BP chart tooltip
  int? _touchedIndex;
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Rebuild when tab changes so the FAB and AppBar actions update.
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() { _loading = false; _error = 'Session expired. Please login again.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _repo.listPatientVitals(
        accessToken: token,
        patientDataId: widget.patientDataId,
      );
      if (!mounted) return;
      setState(() { _vitals = list; _loading = false; });
    } catch (ex) {
      if (!mounted) return;
      setState(() { _error = ex.toString(); _loading = false; });
    }
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  Future<void> _showVitalsDialog({PatientVitalsModel? existing}) async {
    final latest = existing == null && _vitals.isNotEmpty ? _vitals.first : null;
    final formKey = GlobalKey<FormState>();
    final bpSys = TextEditingController(text: existing?.bpSys.toString() ?? '');
    final bpDys = TextEditingController(text: existing?.bpDys.toString() ?? '');
    final bloodSugar = TextEditingController(
      text: existing?.bloodSugar.toString() ?? latest?.bloodSugar.toString() ?? '',
    );
    final pulse = TextEditingController(text: existing?.pulse.toString() ?? '');
    final weightKg = TextEditingController(
      text: existing?.weightKg.toString() ?? latest?.weightKg.toString() ?? '',
    );
    final heightCms = TextEditingController(
      text: existing?.heightCms.toString() ?? latest?.heightCms.toString() ?? '',
    );
    var isActive = existing?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Vitals' : 'Update Vitals'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _numberField(controller: bpSys, label: 'BP Systolic'),
                      const SizedBox(height: 12),
                      _numberField(controller: bpDys, label: 'BP Diastolic'),
                      const SizedBox(height: 12),
                      _numberField(
                        controller: bloodSugar,
                        label: 'Blood Sugar (mg/dL)',
                      ),
                      const SizedBox(height: 12),
                      _numberField(controller: pulse, label: 'Pulse'),
                      const SizedBox(height: 12),
                      _numberField(controller: weightKg, label: 'Weight (kg)'),
                      const SizedBox(height: 12),
                      _numberField(controller: heightCms, label: 'Height (cm)'),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final token = AuthSession.accessToken;
                          if (token == null) {
                            if (!mounted) return;
                            setState(() => _error = 'Session expired. Please login again.');
                            Navigator.of(context).pop();
                            return;
                          }
                          final request = PatientVitalsSaveRequestModel(
                            patientDataId: widget.patientDataId,
                            bpSys: int.parse(bpSys.text.trim()),
                            bpDys: int.parse(bpDys.text.trim()),
                            bloodSugar: int.parse(bloodSugar.text.trim()),
                            pulse: int.parse(pulse.text.trim()),
                            weightKg: int.parse(weightKg.text.trim()),
                            heightCms: int.parse(heightCms.text.trim()),
                            isActive: isActive,
                          );
                          setState(() { _saving = true; _error = null; });
                          try {
                            if (existing == null) {
                              await _repo.createPatientVitals(
                                accessToken: token,
                                patientDataId: widget.patientDataId,
                                request: request,
                              );
                            } else {
                              await _repo.updatePatientVitals(
                                accessToken: token,
                                patientVitalsId: existing.patientVitalsId,
                                request: request,
                              );
                            }
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop(true);
                          } on AuthException catch (ex) {
                            if (!mounted) return;
                            setState(() => _error = ex.message);
                          } catch (ex) {
                            if (!mounted) return;
                            setState(() => _error = ex.toString());
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  child: Text(existing == null ? 'Save' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    bpSys.dispose();
    bpDys.dispose();
    bloodSugar.dispose();
    pulse.dispose();
    weightKg.dispose();
    heightCms.dispose();

    if (saved == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null
              ? 'Patient vitals saved successfully.'
              : 'Patient vitals updated successfully.'),
        ),
      );
    }
  }

  Future<void> _deleteVitals(PatientVitalsModel vitals) async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() => _error = 'Session expired. Please login again.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vitals?'),
        content: const Text('This will remove this vitals entry from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _saving = true; _error = null; });
    try {
      await _repo.deletePatientVitals(
        accessToken: token,
        patientVitalsId: vitals.patientVitalsId,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Patient vitals deleted.')));
    } on AuthException catch (ex) {
      if (!mounted) return;
      setState(() => _error = ex.message);
    } catch (ex) {
      if (!mounted) return;
      setState(() => _error = ex.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) return 'Required';
        final parsed = int.tryParse(trimmed);
        if (parsed == null || parsed <= 0) return 'Enter a valid number';
        return null;
      },
    );
  }

  String _formatRecordedOn(DateTime value) {
    final ist = value.toUtc().add(const Duration(hours: 5, minutes: 30));
    final day = ist.day.toString().padLeft(2, '0');
    final month = _monthNames[ist.month - 1];
    final year = (ist.year % 100).toString().padLeft(2, '0');
    final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final minute = ist.minute.toString().padLeft(2, '0');
    final period = ist.hour >= 12 ? 'PM' : 'AM';
    return '$day-$month-$year $hour:$minute $period IST';
  }

  /// Short date for chart X-axis labels: `dd-MMM-yy`.
  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final mon = _monthNames[d.month - 1];
    final yr = (d.year % 100).toString().padLeft(2, '0');
    return '$day-$mon-$yr';
  }

  // ── Records tab ──────────────────────────────────────────────────────────────

  Widget _buildRecordsList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
        ),
      );
    }
    if (_vitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monitor_heart_outlined, size: 56),
              const SizedBox(height: 12),
              const Text('No vitals recorded yet.'),
              const SizedBox(height: 8),
              Text(
                'Add blood pressure, blood sugar, pulse, weight, and height for ${widget.patientName}.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _vitals.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _vitals[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.monitor_heart, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recorded on ${_formatRecordedOn(item.insertedOn)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showVitalsDialog(existing: item);
                          } else if (value == 'delete') {
                            _deleteVitals(item);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                          PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _metricChip('BP', '${item.bpSys}/${item.bpDys}'),
                      _metricChip('Sugar', '${item.bloodSugar} mg/dL'),
                      _metricChip('Pulse', '${item.pulse} bpm'),
                      _metricChip('Weight', '${item.weightKg} kg'),
                      _metricChip('Height', '${item.heightCms} cm'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── BP Charts tab ────────────────────────────────────────────────────────────

  Widget _buildBpCharts() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
        ),
      );
    }

    // Sort chronologically oldest → newest for the chart
    final sorted = [..._vitals]
      ..sort((a, b) => a.insertedOn.compareTo(b.insertedOn));

    if (sorted.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No vitals recorded yet.\nAdd a vitals entry to see the BP chart.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sysSpots = <FlSpot>[];
    final dysSpots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      sysSpots.add(FlSpot(i.toDouble(), sorted[i].bpSys.toDouble()));
      dysSpots.add(FlSpot(i.toDouble(), sorted[i].bpDys.toDouble()));
    }

    final allBp = sorted
        .expand((v) => [v.bpSys.toDouble(), v.bpDys.toDouble()]);
    final minBp = allBp.reduce(math.min);
    final maxBp = allBp.reduce(math.max);
    final minY = (minBp - 15).clamp(30.0, 110.0);
    final maxY = (maxBp + 20).clamp(100.0, 240.0);

    final n = sorted.length;
    final xInterval = n <= 6
        ? 1.0
        : n <= 12
            ? 2.0
            : (n / 6).ceilToDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Legend & reference card ──────────────────────────────────────────
          _buildBpInfoCard(),
          const SizedBox(height: 20),

          // ── Chart ────────────────────────────────────────────────────────────
          Text(
            'Blood Pressure Trend',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'mmHg over time  •  ${sorted.length} reading${sorted.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (sorted.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 20,
                  verticalInterval: xInterval,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (v) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('mmHg',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                    axisNameSize: 18,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 20,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: xInterval,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= sorted.length) {
                          return const SizedBox();
                        }
                        // Only show at interval boundaries
                        if (v != meta.min &&
                            v != meta.max &&
                            v % xInterval != 0) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _fmtDate(sorted[idx].insertedOn),
                            style: const TextStyle(
                                fontSize: 9, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                // Reference lines for clinical thresholds
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (120 >= minY && 120 <= maxY)
                      HorizontalLine(
                        y: 120,
                        color: Colors.red.withValues(alpha: 0.45),
                        strokeWidth: 1.5,
                        dashArray: [8, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => '120',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (140 >= minY && 140 <= maxY)
                      HorizontalLine(
                        y: 140,
                        color: Colors.red.withValues(alpha: 0.7),
                        strokeWidth: 1.5,
                        dashArray: [8, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => '140',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (80 >= minY && 80 <= maxY)
                      HorizontalLine(
                        y: 80,
                        color: Colors.blue.withValues(alpha: 0.45),
                        strokeWidth: 1.5,
                        dashArray: [8, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => '80',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade400,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (90 >= minY && 90 <= maxY)
                      HorizontalLine(
                        y: 90,
                        color: Colors.blue.withValues(alpha: 0.7),
                        strokeWidth: 1.5,
                        dashArray: [8, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => '90',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                lineBarsData: [
                  // Systolic
                  LineChartBarData(
                    spots: sysSpots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: Colors.red.shade600,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                        radius: sorted.length <= 20 ? 4.5 : 3,
                        color: Colors.red.shade600,
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withValues(alpha: 0.06),
                    ),
                  ),
                  // Diastolic
                  LineChartBarData(
                    spots: dysSpots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: Colors.blue.shade600,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                        radius: sorted.length <= 20 ? 4.5 : 3,
                        color: Colors.blue.shade600,
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withValues(alpha: 0.06),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent || event is FlLongPressEnd) {
                      setState(() => _touchedIndex = null);
                    } else if (response?.lineBarSpots != null &&
                        response!.lineBarSpots!.isNotEmpty) {
                      setState(() =>
                          _touchedIndex = response.lineBarSpots!.first.x.toInt());
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        Colors.blueGrey.shade800.withValues(alpha: 0.92),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) {
                      return spots.asMap().entries.map((entry) {
                        final i = entry.key;
                        final spot = entry.value;
                        final idx = spot.x.toInt();
                        final date = (idx >= 0 && idx < sorted.length)
                            ? _fmtDate(sorted[idx].insertedOn)
                            : '';
                        final isSys = spot.barIndex == 0;
                        return LineTooltipItem(
                          i == 0 ? '$date\n' : '',
                          const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.normal),
                          children: [
                            TextSpan(
                              text:
                                  '${isSys ? 'Systolic' : 'Diastolic'}: ${spot.y.toInt()} mmHg',
                              style: TextStyle(
                                color: isSys
                                    ? Colors.red.shade300
                                    : Colors.blue.shade300,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Data table ───────────────────────────────────────────────────────
          Text(
            'Readings',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildBpDataTable(sorted),
        ],
      ),
    );
  }

  Widget _buildBpInfoCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend
            Row(
              children: [
                _legendDot(Colors.red.shade600),
                const SizedBox(width: 6),
                const Text('Systolic (upper)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 20),
                _legendDot(Colors.blue.shade600),
                const SizedBox(width: 6),
                const Text('Diastolic (lower)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            // Reference ranges
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text('Normal ranges',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _rangeChip('Systolic Normal', '< 120', Colors.red.shade100,
                    Colors.red.shade700),
                _rangeChip('Systolic Elevated', '120–129', Colors.orange.shade100,
                    Colors.orange.shade800),
                _rangeChip('Systolic High', '≥ 130', Colors.red.shade200,
                    Colors.red.shade900),
                _rangeChip('Diastolic Normal', '< 80', Colors.blue.shade100,
                    Colors.blue.shade700),
                _rangeChip('Diastolic High', '≥ 80', Colors.blue.shade200,
                    Colors.blue.shade900),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _rangeChip(String label, String range, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        '$label: $range mmHg',
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildBpDataTable(List<PatientVitalsModel> sorted) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(
        border: TableBorder.all(
          color: colorScheme.outlineVariant,
          width: 0.6,
          borderRadius: BorderRadius.circular(8),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.4),
          2: FlexColumnWidth(1.4),
          3: FlexColumnWidth(1.4),
          4: FlexColumnWidth(1.6),
        },
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
            children: [
              _tableCell('Date', header: true),
              _tableCell('Sys', header: true),
              _tableCell('Dias', header: true),
              _tableCell('Sugar', header: true),
              _tableCell('Status', header: true),
            ],
          ),
          // Rows (newest first from sorted = oldest first, so reverse)
          for (final v in sorted.reversed)
            () {
              final sysOk = v.bpSys < 130;
              final dysOk = v.bpDys < 80;
              final status = (sysOk && dysOk) ? 'Normal' : 'Review';
              final statusColor = (sysOk && dysOk)
                  ? Colors.green.shade700
                  : Colors.orange.shade800;
              final isHighlighted = _touchedIndex != null &&
                  sorted[_touchedIndex!].patientVitalsId == v.patientVitalsId;
              return TableRow(
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : null,
                ),
                children: [
                  _tableCell(_fmtDate(v.insertedOn)),
                  _tableCell('${v.bpSys}',
                      color: sysOk ? null : Colors.red.shade700),
                  _tableCell('${v.bpDys}',
                      color: dysOk ? null : Colors.blue.shade700),
                  _tableCell('${v.bloodSugar}'),
                  _tableCell(status, color: statusColor),
                ],
              );
            }(),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool header = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: header ? 12 : 12,
          fontWeight: header ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
        textAlign: header ? TextAlign.center : TextAlign.center,
      ),
    );
  }

  // ── PDF export ───────────────────────────────────────────────────────────────

  Future<void> _exportBpPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final sorted = [..._vitals]
        ..sort((a, b) => a.insertedOn.compareTo(b.insertedOn));

      final doc = pw.Document();
      final now = DateTime.now();
      final generatedAt =
          '${_fmtDate(now)}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (ctx) => _pdfPageHeader(ctx, generatedAt),
          build: (ctx) => _pdfContent(sorted),
        ),
      );

      await Printing.layoutPdf(onLayout: (_) => doc.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  pw.Widget _pdfPageHeader(pw.Context ctx, String generatedAt) {
    final isFirst = ctx.pageNumber == 1;
    if (isFirst) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        margin: const pw.EdgeInsets.only(bottom: 14),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue900,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'BP Report — ${widget.patientName}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated: $generatedAt',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.blue100),
            ),
          ],
        ),
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(
        'BP Report — ${widget.patientName}',
        style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.blueGrey600,
            fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  List<pw.Widget> _pdfContent(List<PatientVitalsModel> sorted) {
    if (sorted.isEmpty) {
      return [pw.Text('No vitals recorded.')];
    }

    final allBp =
        sorted.expand((v) => [v.bpSys.toDouble(), v.bpDys.toDouble()]);
    final minBp = allBp.reduce(math.min);
    final maxBp = allBp.reduce(math.max);
    final minV = (minBp - 10).clamp(30.0, 110.0);
    final maxV = (maxBp + 10).clamp(100.0, 240.0);
    final range = maxV - minV;

    return [
      // ── Reference ranges ──────────────────────────────────────────────────
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey50,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Normal Ranges',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700)),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              pw.Container(
                  width: 10, height: 10, color: PdfColors.red600),
              pw.SizedBox(width: 5),
              pw.Text('Systolic: Normal <120 | Elevated 120–129 | High ≥130',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.blueGrey700)),
            ]),
            pw.SizedBox(height: 3),
            pw.Row(children: [
              pw.Container(
                  width: 10, height: 10, color: PdfColors.blue600),
              pw.SizedBox(width: 5),
              pw.Text('Diastolic: Normal <80 | High ≥80',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.blueGrey700)),
            ]),
          ],
        ),
      ),
      pw.SizedBox(height: 16),

      // ── Systolic chart ───────────────────────────────────────────────────
      pw.Text('Systolic Blood Pressure',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      _pdfBarChartRow(
          sorted, (v) => v.bpSys.toDouble(), minV, range, PdfColors.red600,
          thresholds: [120, 140]),
      pw.SizedBox(height: 18),

      // ── Diastolic chart ──────────────────────────────────────────────────
      pw.Text('Diastolic Blood Pressure',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      _pdfBarChartRow(
          sorted, (v) => v.bpDys.toDouble(), minV, range, PdfColors.blue600,
          thresholds: [80, 90]),
      pw.SizedBox(height: 20),

      // ── Data table ───────────────────────────────────────────────────────
      pw.Text('Readings',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfDataTable(sorted),
    ];
  }

  /// Widget-based bar chart for a single BP parameter in PDF.
  pw.Widget _pdfBarChartRow(
    List<PatientVitalsModel> sorted,
    double Function(PatientVitalsModel) getValue,
    double minV,
    double range,
    PdfColor barColor, {
    required List<double> thresholds,
  }) {
    const chartH = 56.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Bars
        pw.SizedBox(
          height: chartH,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: sorted.map((v) {
              final val = getValue(v);
              final norm = ((val - minV) / range).clamp(0.0, 1.0);
              final barH = math.max(norm * chartH, 2.0);
              final ok = thresholds.first > 100
                  ? val < thresholds[0]   // systolic: ok if < 130
                  : val < thresholds[0];  // diastolic: ok if < 80
              return pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        height: barH,
                        decoration: pw.BoxDecoration(
                          color: ok ? barColor : PdfColors.orange,
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
        // Baseline
        pw.Container(height: 0.6, color: PdfColors.blueGrey300),
        pw.SizedBox(height: 3),
        // X-axis date labels
        pw.Row(
          children: sorted.map((v) {
            return pw.Expanded(
              child: pw.Text(
                _fmtDate(v.insertedOn),
                style: pw.TextStyle(
                    fontSize: 6, color: PdfColors.blueGrey600),
                textAlign: pw.TextAlign.center,
              ),
            );
          }).toList(),
        ),
        // Threshold legend
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Container(
              width: 10, height: 1.5, color: PdfColors.orange700),
          pw.SizedBox(width: 4),
          pw.Text(
            'Review threshold: ${thresholds[0].toInt()} mmHg',
            style: pw.TextStyle(
                fontSize: 7, color: PdfColors.blueGrey600),
          ),
        ]),
      ],
    );
  }

  pw.Widget _pdfDataTable(List<PatientVitalsModel> sorted) {
    return pw.Table(
      border: pw.TableBorder.all(
          color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColors.blueGrey50),
          children: [
            _pdfCell('Date', header: true),
            _pdfCell('Systolic', header: true),
            _pdfCell('Diastolic', header: true),
            _pdfCell('Sugar', header: true),
            _pdfCell('Status', header: true),
          ],
        ),
        ...sorted.reversed.map((v) {
          final ok = v.bpSys < 130 && v.bpDys < 80;
          return pw.TableRow(children: [
            _pdfCell(_fmtDate(v.insertedOn)),
            _pdfCell('${v.bpSys} mmHg',
                color: v.bpSys >= 130 ? PdfColors.red700 : null),
            _pdfCell('${v.bpDys} mmHg',
                color: v.bpDys >= 80 ? PdfColors.blue700 : null),
            _pdfCell('${v.bloodSugar} mg/dL'),
            _pdfCell(ok ? 'Normal' : 'Review',
                color: ok ? PdfColors.green700 : PdfColors.orange700),
          ]);
        }),
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
          color: color ??
              (header ? PdfColors.blueGrey800 : PdfColors.black),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final onChartsTab = _tabController.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.patientName} — Vitals'),
        actions: [
          if (onChartsTab)
            _exportingPdf
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Export BP report as PDF',
                    onPressed: _vitals.isEmpty ? null : _exportBpPdf,
                  ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_outlined), text: 'Records'),
            Tab(icon: Icon(Icons.show_chart), text: 'BP Charts'),
          ],
        ),
      ),
      // FAB only on the Records tab
      floatingActionButton: onChartsTab
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : () => _showVitalsDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Vitals'),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecordsList(),
          _buildBpCharts(),
        ],
      ),
    );
  }
}
