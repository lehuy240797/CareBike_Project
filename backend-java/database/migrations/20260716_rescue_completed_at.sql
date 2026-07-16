SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.rescues', 'completed_at') IS NULL
BEGIN
    ALTER TABLE dbo.rescues
        ADD completed_at DATETIME2 NULL;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes i
    INNER JOIN sys.index_columns ic
        ON ic.object_id = i.object_id
       AND ic.index_id = i.index_id
    WHERE i.object_id = OBJECT_ID('dbo.rescues')
      AND COL_NAME(ic.object_id, ic.column_id) = 'completed_at'
)
BEGIN
    CREATE INDEX IX_rescues_completed_at
        ON dbo.rescues(completed_at);
END;
GO
