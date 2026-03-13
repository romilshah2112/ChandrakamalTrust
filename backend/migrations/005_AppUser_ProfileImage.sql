IF COL_LENGTH('dbo.AppUser', 'ProfileImage') IS NULL
BEGIN
    ALTER TABLE dbo.AppUser
    ADD ProfileImage nvarchar(1000) NULL;
END
