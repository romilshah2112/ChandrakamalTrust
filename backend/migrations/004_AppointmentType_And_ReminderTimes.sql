-- Migration: AppointmentType table (first-time / follow-up visitors) and reminder times
-- ReminderHoursBefore = hours before appointment to send reminder; FollowUpReminderHoursAfter = hours after visit to send follow-up.

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AppointmentType')
BEGIN
    CREATE TABLE [AppointmentType] (
        [lAppointmentTypeId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [AppointmentTypeName] NVARCHAR(100) NOT NULL,
        [ReminderHoursBefore] INT NOT NULL DEFAULT 24,
        [FollowUpReminderHoursAfter] INT NOT NULL DEFAULT 0,
        [Description] NVARCHAR(500) NULL
    );

    INSERT INTO [AppointmentType] ([AppointmentTypeName], [ReminderHoursBefore], [FollowUpReminderHoursAfter], [Description])
    VALUES
        (N'First Visit', 48, 24, N'First-time visitor; reminder 48h before; follow-up 24h after'),
        (N'Follow-up', 24, 24, N'Follow-up visitor; reminder 24h before; follow-up 24h after');
END;

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PatientAppointment' AND COLUMN_NAME = 'lAppointmentTypeId'
)
BEGIN
    ALTER TABLE [PatientAppointment]
    ADD [lAppointmentTypeId] INT NULL;

    ALTER TABLE [PatientAppointment]
    ADD CONSTRAINT [FK_PatientAppointment_AppointmentType]
    FOREIGN KEY ([lAppointmentTypeId]) REFERENCES [AppointmentType]([lAppointmentTypeId]);

    -- Optional: default existing rows to Follow-up (id 2) so reminder logic applies
    -- UPDATE [PatientAppointment] SET [lAppointmentTypeId] = 2 WHERE [lAppointmentTypeId] IS NULL;
END;
