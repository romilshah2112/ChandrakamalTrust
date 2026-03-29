-- Optional: Create RecordType lookup if your database does not already have it.
-- The API expects columns [lRecordTypeId] and [Record] (same pattern as ReferenceType).

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RecordType')
BEGIN
    CREATE TABLE [RecordType] (
        [lRecordTypeId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [Record] NVARCHAR(100) NOT NULL
    );
    INSERT INTO [RecordType] ([Record]) VALUES
        (N'Lab Report'),
        (N'X-Ray'),
        (N'ECG'),
        (N'Prescription'),
        (N'Other');
END;
