# Database Migrations

Run SQL scripts in order against your database.

1. `002_PatientComplaint_And_PatientMedicalHistory.sql` - Creates PatientComplaint and PatientMedicalHistory tables for consultation notes.

2. `003_AppointmentFollowUpReminder.sql` - Ensures ReminderSent column exists on PatientAppointment (used for follow-up reminder sent flag).

3. `004_AppointmentType_And_ReminderTimes.sql` - Creates AppointmentType table (First Visit / Follow-up with ReminderHoursBefore and FollowUpReminderHoursAfter) and adds lAppointmentTypeId to PatientAppointment.
