IF OBJECT_ID(N'dbo.vehicle_tire_specs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.vehicle_tire_specs (
        id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        brand NVARCHAR(80) NOT NULL,
        vehicle_name NVARCHAR(120) NOT NULL,
        vehicle_type NVARCHAR(50) NOT NULL,
        engine_capacity INT NULL,
        front_tire_size NVARCHAR(60) NOT NULL,
        rear_tire_size NVARCHAR(60) NOT NULL,
        note NVARCHAR(255) NULL,
        CONSTRAINT uk_vehicle_tire_specs_vehicle UNIQUE (
            brand,
            vehicle_name,
            vehicle_type,
            engine_capacity
        )
    );
END;
GO

MERGE dbo.vehicle_tire_specs AS target
USING (VALUES
    (N'Honda', N'Airblade', N'XE_TAY_GA', 160, N'90/80-14M/C 43P', N'100/80-14', N'Default tire specification. Verify exact year and model variant before use.'),
    (N'Honda', N'Winner', N'XE_SO', 150, N'90/80-17', N'120/70-17', N'Default tire specification. Verify exact year and model variant before use.')
) AS source (
    brand,
    vehicle_name,
    vehicle_type,
    engine_capacity,
    front_tire_size,
    rear_tire_size,
    note
)
ON target.brand = source.brand
   AND target.vehicle_name = source.vehicle_name
   AND target.vehicle_type = source.vehicle_type
   AND (
        target.engine_capacity = source.engine_capacity
        OR (target.engine_capacity IS NULL AND source.engine_capacity IS NULL)
   )
WHEN MATCHED THEN
    UPDATE SET
        front_tire_size = source.front_tire_size,
        rear_tire_size = source.rear_tire_size,
        note = source.note
WHEN NOT MATCHED THEN
    INSERT (
        brand,
        vehicle_name,
        vehicle_type,
        engine_capacity,
        front_tire_size,
        rear_tire_size,
        note
    )
    VALUES (
        source.brand,
        source.vehicle_name,
        source.vehicle_type,
        source.engine_capacity,
        source.front_tire_size,
        source.rear_tire_size,
        source.note
    );
GO
