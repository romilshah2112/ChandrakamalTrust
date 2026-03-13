-- Migration: Create PatientComplaint and PatientMedicalHistory tables for consultation notes
-- Run this against your database (e.g. HealthCareContext) before using the save consultation notes feature.

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PatientComplaint')
BEGIN
    CREATE TABLE [PatientComplaint] (
        [lPatientComplaintId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [lPatientDataId] INT NOT NULL,
        [Complaint] NVARCHAR(MAX) NOT NULL DEFAULT '',
        [Symptoms] NVARCHAR(MAX) NOT NULL DEFAULT '',
        [ConsultationDate] DATETIME NOT NULL DEFAULT GETUTCDATE(),
        [lDoctorProfileId] INT NULL,
        [lEnteredById] INT NOT NULL,
        [InsertedOn] DATETIME NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT [FK_PatientComplaint_PatientData] FOREIGN KEY ([lPatientDataId]) REFERENCES [patientdata]([lPatientDataId]),
        CONSTRAINT [FK_PatientComplaint_DoctorProfile] FOREIGN KEY ([lDoctorProfileId]) REFERENCES [DoctorProfile]([lDoctorProfileId])
    );
    CREATE INDEX [IX_PatientComplaint_PatientDataId] ON [PatientComplaint]([lPatientDataId]);
    CREATE INDEX [IX_PatientComplaint_ConsultationDate] ON [PatientComplaint]([ConsultationDate]);
END;

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PatientMedicalHistory')
BEGIN
    CREATE TABLE [PatientMedicalHistory] (
        [lPatientMedicalHistoryId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [lPatientDataId] INT NOT NULL,
        [HistoryText] NVARCHAR(MAX) NOT NULL DEFAULT '',
        [RecordedDate] DATETIME NOT NULL DEFAULT GETUTCDATE(),
        [lEnteredById] INT NOT NULL,
        [InsertedOn] DATETIME NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT [FK_PatientMedicalHistory_PatientData] FOREIGN KEY ([lPatientDataId]) REFERENCES [patientdata]([lPatientDataId])
    );
    CREATE INDEX [IX_PatientMedicalHistory_PatientDataId] ON [PatientMedicalHistory]([lPatientDataId]);
    CREATE INDEX [IX_PatientMedicalHistory_RecordedDate] ON [PatientMedicalHistory]([RecordedDate]);
END;
