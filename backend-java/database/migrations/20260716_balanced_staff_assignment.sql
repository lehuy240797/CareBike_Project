SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH('dbo.appointments', 'assigned_staff_id') IS NULL
BEGIN
    ALTER TABLE dbo.appointments
        ADD assigned_staff_id INT NULL;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.foreign_key_columns fkc
    WHERE fkc.parent_object_id = OBJECT_ID('dbo.appointments')
      AND COL_NAME(fkc.parent_object_id, fkc.parent_column_id) = 'assigned_staff_id'
)
BEGIN
    ALTER TABLE dbo.appointments
        ADD CONSTRAINT FK_appointments_assigned_staff
        FOREIGN KEY (assigned_staff_id) REFERENCES dbo.staffs(id);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes i
    INNER JOIN sys.index_columns ic
        ON ic.object_id = i.object_id
       AND ic.index_id = i.index_id
    WHERE i.object_id = OBJECT_ID('dbo.appointments')
      AND COL_NAME(ic.object_id, ic.column_id) = 'assigned_staff_id'
)
BEGIN
    CREATE INDEX IX_appointments_assigned_staff_id
        ON dbo.appointments(assigned_staff_id);
END;
GO
