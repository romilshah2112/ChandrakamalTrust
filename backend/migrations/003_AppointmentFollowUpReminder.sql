-- Migration: Ensure ReminderSent exists on PatientAppointment (used for follow-up reminder sent flag).
-- If your table already has ReminderSent, this is a no-op.

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PatientAppointment' AND COLUMN_NAME = 'ReminderSent'
)
BEGIN
    ALTER TABLE [PatientAppointment]
    ADD [ReminderSent] BIT NOT NULL DEFAULT 0;
END;
