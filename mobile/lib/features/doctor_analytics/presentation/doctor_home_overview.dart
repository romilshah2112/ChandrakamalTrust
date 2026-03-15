import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/doctor_analytics/data/doctor_analytics_repository.dart';
import 'package:optima_healthcare_mobile/features/doctor_analytics/models/doctor_dashboard_analytics_model.dart';

class DoctorHomeOverview extends StatefulWidget {
  const DoctorHomeOverview({super.key});

  @override
  State<DoctorHomeOverview> createState() => _DoctorHomeOverviewState();
}

class _DoctorHomeOverviewState extends State<DoctorHomeOverview> {
  final _repo = DoctorAnalyticsRepository();

  bool _loading = true;
  String? _error;
  List<DoctorAppointmentSummaryModel> _appointments = const [];

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
        _appointments = analytics.todayAppointments;
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
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Appointments",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else if (!_loading && _appointments.isEmpty)
              Text(
                'No appointments scheduled for today.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ..._appointments.take(5).map(_appointmentTile),
          ],
        ),
      ),
    );
  }

  Widget _appointmentTile(DoctorAppointmentSummaryModel appointment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFCB4E42),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.patientName.isEmpty
                      ? 'Patient'
                      : appointment.patientName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_timeLabel(appointment.startTime)} - ${_timeLabel(appointment.endTime)}${appointment.clinicName.isEmpty ? '' : ' | ${appointment.clinicName}'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $suffix';
  }
}
