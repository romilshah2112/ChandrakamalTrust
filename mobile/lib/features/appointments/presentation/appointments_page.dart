import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/theme.dart';
import 'package:optima_healthcare_mobile/features/admin/models/clinic_schedule_model.dart';
import 'package:optima_healthcare_mobile/features/appointments/data/appointment_repository.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/lookup_option_model.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/patient_appointment_model.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:table_calendar/table_calendar.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  static const int _appointmentDurationMinutes = 15;
  final _repo = AppointmentRepository();

  List<LookupOptionModel> _statusOptions = const [];
  List<LookupOptionModel> _typeOptions = const [];
  List<LookupOptionModel> _patients = const [];
  List<LookupOptionModel> _doctors = const [];
  List<LookupOptionModel> _clinics = const [];
  List<ClinicScheduleModel> _clinicSchedules = const [];
  List<PatientAppointmentModel> _appointments = const [];

  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  int? _selectedClinicId;

  bool get _canEdit {
    final role = (AuthSession.role ?? '').toLowerCase();
    return role.contains('admin') ||
        role.contains('doctor') ||
        role.contains('receptionist');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({DateTime? forMonth, int? clinicIdOverride}) async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Session expired. Please login again.';
      });
      return;
    }

    final targetMonth = forMonth ?? _focusedDay;
    final monthStart = DateTime(targetMonth.year, targetMonth.month, 1);
    final monthEnd = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final statuses = await _repo.listStatusLookup(accessToken: token);
      final clinics = await _repo.listClinicLookup(accessToken: token);
      final schedules = await _repo.listClinicScheduleLookup(
        accessToken: token,
      );

      List<LookupOptionModel> patients = const [];
      List<LookupOptionModel> doctors = const [];
      List<LookupOptionModel> typeOptions = const [];

      if (_canEdit) {
        patients = await _repo.listPatientLookup(accessToken: token);
        doctors = await _repo.listDoctorLookup(accessToken: token);
        typeOptions = await _repo.listAppointmentTypeLookup(accessToken: token);
      }

      final selectedClinicId = _resolveClinicId(
        clinics,
        clinicIdOverride ?? _selectedClinicId,
      );

      final appointments = selectedClinicId == null
          ? const <PatientAppointmentModel>[]
          : await _repo.listAppointments(
              accessToken: token,
              from: monthStart,
              to: monthEnd,
              clinicId: selectedClinicId,
            );

      setState(() {
        _statusOptions = statuses;
        _clinics = clinics;
        _clinicSchedules = schedules;
        _patients = patients;
        _doctors = doctors;
        _typeOptions = typeOptions;
        _selectedClinicId = selectedClinicId;
        _appointments = appointments;
        _focusedDay = targetMonth;
      });
    } catch (ex) {
      setState(() {
        _error = ex.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  int? _resolveClinicId(List<LookupOptionModel> clinics, int? requestedId) {
    if (clinics.isEmpty) {
      return null;
    }
    if (requestedId != null && clinics.any((c) => c.id == requestedId)) {
      return requestedId;
    }
    return clinics.first.id;
  }

  List<PatientAppointmentModel> get _selectedDayAppointments {
    return _appointmentsForDay(_selectedDate);
  }

  List<PatientAppointmentModel> _appointmentsForDay(DateTime day) {
    return _appointments.where((a) => _isSameDate(a.startTime, day)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  _ClinicScheduleWindow? _selectedDayWindow(DateTime day) {
    final clinicId = _selectedClinicId;
    if (clinicId == null) {
      return null;
    }

    ClinicScheduleModel? schedule;
    for (final item in _clinicSchedules) {
      if (item.clinicId == clinicId && item.dayOfWeek == day.weekday) {
        schedule = item;
        break;
      }
    }

    if (schedule == null) {
      return null;
    }

    return _ClinicScheduleWindow(
      isClosed: schedule.isClosed,
      open: _parseScheduleTime(day, schedule.openTime),
      close: _parseScheduleTime(day, schedule.closeTime),
    );
  }

  DateTime? _parseScheduleTime(DateTime day, String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  List<DateTime> _timeSlotsForDay(DateTime day) {
    final window = _selectedDayWindow(day);
    if (window == null ||
        window.isClosed ||
        window.open == null ||
        window.close == null) {
      return const [];
    }

    final slots = <DateTime>[];
    var current = window.open!;
    while (!current
        .add(const Duration(minutes: _appointmentDurationMinutes))
        .isAfter(window.close!)) {
      slots.add(current);
      current = current.add(const Duration(minutes: _appointmentDurationMinutes));
    }
    return slots;
  }

  bool _hasOverlap(
    DateTime slotStart,
    DateTime slotEnd,
    List<PatientAppointmentModel> appointments,
  ) {
    for (final appointment in appointments) {
      if (slotStart.isBefore(appointment.endTime) &&
          slotEnd.isAfter(appointment.startTime)) {
        return true;
      }
    }
    return false;
  }

  int _freeSlotsForDay(DateTime day) {
    final slots = _timeSlotsForDay(day);
    if (slots.isEmpty) {
      return 0;
    }

    final appointments = _appointmentsForDay(day);
    final now = DateTime.now();
    var free = 0;

    for (final slotStart in slots) {
      final slotEnd = slotStart.add(
        const Duration(minutes: _appointmentDurationMinutes),
      );
      final isPast = slotEnd.isBefore(now);
      final isBooked = _hasOverlap(slotStart, slotEnd, appointments);
      if (!isPast && !isBooked) {
        free++;
      }
    }

    return free;
  }

  List<_AvailabilitySlot> _availabilityForSelectedDay() {
    if (_selectedClinicId == null) {
      return const [
        _AvailabilitySlot(
          label: 'No clinic selected.',
          type: _AvailabilityType.info,
        ),
      ];
    }

    final window = _selectedDayWindow(_selectedDate);
    if (window == null) {
      return const [
        _AvailabilitySlot(
          label: 'Clinic schedule is not configured for this day.',
          type: _AvailabilityType.info,
        ),
      ];
    }

    if (window.isClosed) {
      return const [
        _AvailabilitySlot(
          label: 'Clinic is closed on this day.',
          type: _AvailabilityType.info,
        ),
      ];
    }

    if (window.open == null || window.close == null) {
      return const [
        _AvailabilitySlot(
          label: 'Clinic opening hours are not configured for this day.',
          type: _AvailabilityType.info,
        ),
      ];
    }

    final now = DateTime.now();
    final appointments = _appointmentsForDay(_selectedDate);
    final slots = <_AvailabilitySlot>[];

    for (final slotStart in _timeSlotsForDay(_selectedDate)) {
      final slotEnd = slotStart.add(
        const Duration(minutes: _appointmentDurationMinutes),
      );
      final isPast = slotEnd.isBefore(now);
      final isBooked = _hasOverlap(slotStart, slotEnd, appointments);
      final label = '${_fmtTime(slotStart)} - ${_fmtTime(slotEnd)}';

      if (isPast) {
        slots.add(
          _AvailabilitySlot(
            label: 'Past: $label',
            type: _AvailabilityType.past,
          ),
        );
      } else if (isBooked) {
        slots.add(
          _AvailabilitySlot(
            label: 'Booked: $label',
            type: _AvailabilityType.booked,
          ),
        );
      } else {
        slots.add(
          _AvailabilitySlot(
            label: 'Available: $label',
            type: _AvailabilityType.available,
          ),
        );
      }
    }

    return slots;
  }

  bool _isWithinClinicSchedule(DateTime start, DateTime end) {
    if (!_isSameDate(start, end)) {
      return false;
    }
    final window = _selectedDayWindow(start);
    if (window == null ||
        window.isClosed ||
        window.open == null ||
        window.close == null) {
      return false;
    }
    return !start.isBefore(window.open!) && !end.isAfter(window.close!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appointments Calendar')),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Appointment'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _clinicSelectorCard(),
                  const SizedBox(height: 10),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TableCalendar<PatientAppointmentModel>(
                        firstDay: DateTime(2020, 1, 1),
                        lastDay: DateTime(2100, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            _isSameDate(day, _selectedDate),
                        currentDay: DateTime.now(),
                        eventLoader: (day) => _appointmentsForDay(day),
                        onDaySelected: (selected, focused) {
                          setState(() {
                            _selectedDate = selected;
                            _focusedDay = focused;
                          });
                        },
                        onPageChanged: (focused) {
                          final monthChanged = !_isSameMonth(
                            _focusedDay,
                            focused,
                          );
                          setState(() => _focusedDay = focused);
                          if (monthChanged) {
                            _load(forMonth: focused);
                          }
                        },
                        calendarStyle: CalendarStyle(
                          selectedDecoration: const BoxDecoration(
                            color: AppTheme.brandRed,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: AppTheme.brandRed.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          outsideDaysVisible: false,
                          markerDecoration: const BoxDecoration(
                            color: AppTheme.brandRed,
                            shape: BoxShape.circle,
                          ),
                          markersAlignment: Alignment.bottomCenter,
                          markersMaxCount: 3,
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          leftChevronIcon: const Icon(Icons.chevron_left),
                          rightChevronIcon: const Icon(Icons.chevron_right),
                          titleTextStyle: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, day, events) {
                            final bookedCount = events.length;
                            final freeCount = _freeSlotsForDay(day);
                            if (bookedCount == 0 && freeCount == 0) {
                              return null;
                            }
                            return Positioned(
                              bottom: 2,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (freeCount > 0)
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.accentGreen,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          freeCount > 9 ? '9+' : '$freeCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (freeCount > 0 && bookedCount > 0)
                                    const SizedBox(width: 4),
                                  if (bookedCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandRed,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        bookedCount > 9 ? '9+' : '$bookedCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Green = free slots, Red = booked appointments for the selected clinic',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Appointments on ${_fmtShortDate(_selectedDate)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_selectedDayAppointments.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No appointments for this date.'),
                      ),
                    )
                  else
                    ..._selectedDayAppointments.map(_appointmentCard),
                  const SizedBox(height: 12),
                  Text(
                    _canEdit ? 'Day Availability' : 'Available/Booked Slots',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _LegendChip(
                        label: 'Available',
                        color: Color(0xFFD7F5DD),
                        icon: Icons.check_circle_outline,
                      ),
                      _LegendChip(
                        label: 'Booked',
                        color: Color(0xFFFFE0D5),
                        icon: Icons.block_outlined,
                      ),
                      _LegendChip(
                        label: 'Past',
                        color: Color(0xFFE4E4E4),
                        icon: Icons.history,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: _availabilityForSelectedDay()
                            .map(_availabilityTile)
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _clinicSelectorCard() {
    if (_clinics.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.local_hospital_outlined),
          title: Text('No clinics available'),
          subtitle: Text(
            'Please create a clinic before managing appointments.',
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<int>(
          initialValue: _selectedClinicId,
          decoration: InputDecoration(
            labelText: 'Clinic',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.local_hospital_outlined),
          ),
          items: _clinics
              .map(
                (clinic) => DropdownMenuItem<int>(
                  value: clinic.id,
                  child: Text(clinic.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null || value == _selectedClinicId) {
              return;
            }
            setState(() {
              _selectedClinicId = value;
            });
            _load(forMonth: _focusedDay, clinicIdOverride: value);
          },
        ),
      ),
    );
  }

  Widget _appointmentCard(PatientAppointmentModel appointment) {
    final start = _fmtTime(appointment.startTime);
    final end = _fmtTime(appointment.endTime);
    final statusName = _statusLabel(appointment.appointmentStatusId);
    final isPast = appointment.endTime.isBefore(DateTime.now());
    final cardColor = isPast
        ? Colors.grey.withValues(alpha: 0.12)
        : statusName.toLowerCase().contains('cancel')
        ? Colors.red.withValues(alpha: 0.10)
        : statusName.toLowerCase().contains('complete')
        ? Colors.green.withValues(alpha: 0.10)
        : Colors.blue.withValues(alpha: 0.10);

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        title: Text('$start - $end'),
        subtitle: Text(
          'Patient: ${appointment.patientName}\nDoctor: ${appointment.doctorName}\nStatus: $statusName${(appointment.appointmentTypeName ?? '').isNotEmpty ? '\nType: ${appointment.appointmentTypeName}' : ''}',
        ),
        isThreeLine: true,
        trailing: _canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showEditDialog(existing: appointment),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () =>
                        _confirmDelete(appointment.patientAppointmentId),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: const Text(
          'Are you sure you want to delete this appointment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (yes != true) {
      return;
    }

    final token = AuthSession.accessToken;
    if (token == null) {
      return;
    }

    try {
      await _repo.deleteAppointment(accessToken: token, id: id);
      await _load();
    } catch (ex) {
      _showError(ex.toString());
    }
  }

  Future<void> _showEditDialog({PatientAppointmentModel? existing}) async {
    if (!_canEdit) {
      return;
    }
    if (_selectedClinicId == null) {
      _showError('Please select a clinic first.');
      return;
    }
    if (_patients.isEmpty || _doctors.isEmpty || _statusOptions.isEmpty) {
      _showError('Lookups are not ready. Please refresh and try again.');
      return;
    }

    var selectedPatientId = _pickValidOptionId(
      options: _patients,
      requestedId: existing?.patientDataId,
    );
    var selectedDoctorId = _pickValidOptionId(
      options: _doctors,
      requestedId: existing?.doctorProfileId,
    );
    var selectedStatusId = _pickValidOptionId(
      options: _statusOptions,
      requestedId: existing?.appointmentStatusId,
    );
    final typeOptions = _typeOptions;
    var selectedTypeId = typeOptions.isNotEmpty
        ? _pickValidOptionId(
            options: typeOptions,
            requestedId: existing?.appointmentTypeId,
          )
        : existing?.appointmentTypeId ?? 0;
    var notified = (existing?.isNotified ?? 0) == 1;

    var startDateTime = existing?.startTime ?? _defaultStartTimeForSelectedDate();
    var endDateTime = startDateTime.add(
      const Duration(minutes: _appointmentDurationMinutes),
    );
    final availableStartTimes = _availableStartTimesForSelectedDay(
      existingAppointmentId: existing?.patientAppointmentId,
      existingStartTime: existing?.startTime,
    );
    final startTimeController = TextEditingController(
      text: _fmtTime(startDateTime),
    );
    if (availableStartTimes.isEmpty && existing == null) {
      _showError('No available appointment times for the selected date.');
      return;
    }
    if (availableStartTimes.isNotEmpty &&
        !availableStartTimes.any((slot) => slot == startDateTime)) {
      startDateTime = availableStartTimes.first;
      endDateTime = startDateTime.add(
        const Duration(minutes: _appointmentDurationMinutes),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        existing == null
                            ? 'Add Appointment'
                            : 'Update Appointment',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _dropdownField(
                                label: 'Patient',
                                value: selectedPatientId,
                                options: _patients,
                                onChanged: (v) =>
                                    setLocalState(() => selectedPatientId = v),
                              ),
                              const SizedBox(height: 10),
                              _dropdownField(
                                label: 'Doctor',
                                value: selectedDoctorId,
                                options: _doctors,
                                onChanged: (v) =>
                                    setLocalState(() => selectedDoctorId = v),
                              ),
                              const SizedBox(height: 10),
                              _dropdownField(
                                label: 'Status',
                                value: selectedStatusId,
                                options: _statusOptions,
                                onChanged: (v) =>
                                    setLocalState(() => selectedStatusId = v),
                              ),
                              if (typeOptions.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _dropdownField(
                                  label: 'Type',
                                  value: selectedTypeId,
                                  options: typeOptions,
                                  onChanged: (v) =>
                                      setLocalState(() => selectedTypeId = v),
                                ),
                              ],
                              const SizedBox(height: 10),
                              SwitchListTile(
                                title: const Text('Notified'),
                                value: notified,
                                onChanged: (v) =>
                                    setLocalState(() => notified = v),
                              ),
                              const SizedBox(height: 4),
                              ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                tileColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                title: const Text('Appointment Date'),
                                subtitle: Text(_fmtShortDate(_selectedDate)),
                                trailing: const Icon(Icons.calendar_today),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: startTimeController,
                                keyboardType: TextInputType.datetime,
                                decoration: InputDecoration(
                                  labelText: 'Start Time',
                                  hintText: 'HH:mm',
                                  helperText: availableStartTimes.isEmpty
                                      ? 'No available slots'
                                      : 'Available: ${availableStartTimes.map(_fmtTime).join(', ')}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                tileColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                title: const Text('End Time'),
                                subtitle: Text(_fmtDateTime(endDateTime)),
                                trailing: const Icon(Icons.schedule),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final parsedStartTime = _parseSelectedTime(
                                startTimeController.text,
                              );
                              if (parsedStartTime == null) {
                                _showError(
                                  'Enter start time in HH:mm format.',
                                );
                                return;
                              }
                              startDateTime = parsedStartTime;
                              endDateTime = startDateTime.add(
                                const Duration(
                                  minutes: _appointmentDurationMinutes,
                                ),
                              );
                              final matchesAvailableSlot = availableStartTimes
                                  .any((slot) => slot == startDateTime);
                              if (!matchesAvailableSlot) {
                                _showError(
                                  'Entered time is not available for the selected date.',
                                );
                                return;
                              }
                              if (!_isWithinClinicSchedule(
                                startDateTime,
                                endDateTime,
                              )) {
                                _showError(
                                  'Selected time is outside the clinic schedule for this day.',
                                );
                                return;
                              }

                              final token = AuthSession.accessToken;
                              final clinicId = _selectedClinicId;
                              if (token == null || clinicId == null) {
                                return;
                              }

                              try {
                                await _repo.saveAppointment(
                                  accessToken: token,
                                  id: existing?.patientAppointmentId,
                                  body: {
                                    'patientDataId': selectedPatientId,
                                    'doctorProfileId': selectedDoctorId,
                                    'clinicId': clinicId,
                                    'startTime': startDateTime.toIso8601String(),
                                    'endTime': endDateTime.toIso8601String(),
                                    'appointmentStatusId': selectedStatusId,
                                    if (selectedTypeId > 0)
                                      'appointmentTypeId': selectedTypeId,
                                    'isNotified': notified ? 1 : 0,
                                    'isActive': true,
                                  },
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                await _load();
                              } catch (ex) {
                                _showError(ex.toString());
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dropdownField({
    required String label,
    required int value,
    required List<LookupOptionModel> options,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: options
          .map((o) => DropdownMenuItem<int>(value: o.id, child: Text(o.name)))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          onChanged(v);
        }
      },
    );
  }

  Widget _availabilityTile(_AvailabilitySlot slot) {
    final isAvailable = slot.type == _AvailabilityType.available;
    final isBooked = slot.type == _AvailabilityType.booked;
    final isInfo = slot.type == _AvailabilityType.info;
    final bgColor = isAvailable
        ? const Color(0xFFD7F5DD)
        : isBooked
        ? const Color(0xFFFFE0D5)
        : const Color(0xFFE4E4E4);
    final icon = isAvailable
        ? Icons.check_circle_outline
        : isBooked
        ? Icons.block_outlined
        : isInfo
        ? Icons.info_outline
        : Icons.history;
    final iconColor = isAvailable
        ? Colors.green.shade700
        : isBooked
        ? Colors.deepOrange.shade700
        : Colors.grey.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: iconColor),
        title: Text(slot.label),
      ),
    );
  }

  DateTime _defaultStartTimeForSelectedDate() {
    final available = _availableStartTimesForSelectedDay();
    if (available.isNotEmpty) {
      return available.first;
    }
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      10,
      0,
    );
  }

  List<DateTime> _availableStartTimesForSelectedDay({
    int? existingAppointmentId,
    DateTime? existingStartTime,
  }) {
    final now = DateTime.now();
    final dayAppointments = _appointmentsForDay(_selectedDate)
        .where((appointment) =>
            existingAppointmentId == null ||
            appointment.patientAppointmentId != existingAppointmentId)
        .toList();

    final available = _timeSlotsForDay(_selectedDate).where((slotStart) {
      final slotEnd = slotStart.add(
        const Duration(minutes: _appointmentDurationMinutes),
      );
      if (slotEnd.isBefore(now)) {
        return false;
      }
      return !_hasOverlap(slotStart, slotEnd, dayAppointments);
    }).toList();

    if (existingStartTime != null &&
        _isSameDate(existingStartTime, _selectedDate) &&
        !available.any((slot) => slot == existingStartTime)) {
      available.add(existingStartTime);
      available.sort();
    }

    return available;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  int _pickValidOptionId({
    required List<LookupOptionModel> options,
    required int? requestedId,
  }) {
    if (options.isEmpty) {
      return 0;
    }
    if (requestedId == null) {
      return options.first.id;
    }
    final exists = options.any((o) => o.id == requestedId);
    return exists ? requestedId : options.first.id;
  }

  String _statusLabel(int statusId) {
    for (final s in _statusOptions) {
      if (s.id == statusId) {
        return s.name;
      }
    }
    return 'Status #$statusId';
  }

  String _fmtTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _fmtShortDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[value.month - 1];
    final year = (value.year % 100).toString().padLeft(2, '0');
    return '${value.day.toString().padLeft(2, '0')}-$month-$year';
  }

  String _fmtDateTime(DateTime value) =>
      '${_fmtShortDate(value)} ${_fmtTime(value)}';

  DateTime? _parseSelectedTime(String raw) {
    final clean = raw.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(clean);
    if (match == null) {
      return null;
    }

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      minute,
    );
  }

  void _showError(String raw) {
    final message = raw.replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AvailabilityType { available, booked, past, info }

class _AvailabilitySlot {
  const _AvailabilitySlot({required this.label, required this.type});

  final String label;
  final _AvailabilityType type;
}

class _ClinicScheduleWindow {
  const _ClinicScheduleWindow({
    required this.isClosed,
    required this.open,
    required this.close,
  });

  final bool isClosed;
  final DateTime? open;
  final DateTime? close;
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}
