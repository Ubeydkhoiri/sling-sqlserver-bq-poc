USE SlingPOC;
GO

DECLARE @i INT = 1;

WHILE @i <= 50
BEGIN
    INSERT INTO dbo.customers (
        customer_id, customer_name, email, city,
        created_at, updated_at
    )
    VALUES (
        @i,
        CONCAT('Customer ', @i),
        CONCAT('customer', @i, '@example.com'),
        CASE @i % 5
            WHEN 0 THEN 'Jakarta'
            WHEN 1 THEN 'Bekasi'
            WHEN 2 THEN 'Bandung'
            WHEN 3 THEN 'Surabaya'
            ELSE 'Semarang'
        END,
        DATEADD(DAY, -@i, SYSDATETIME()),
        DATEADD(DAY, -@i, SYSDATETIME())
    );

    SET @i += 1;
END;
GO

DECLARE @i INT = 1;

WHILE @i <= 50
BEGIN
    INSERT INTO dbo.orders (
        order_id, customer_id, order_date, product_name,
        quantity, unit_price, order_status, created_at, updated_at
    )
    VALUES (
        1000 + @i,
        ((@i - 1) % 50) + 1,
        CAST(DATEADD(DAY, -@i, SYSDATETIME()) AS DATE),
        CASE @i % 5
            WHEN 0 THEN 'Laptop'
            WHEN 1 THEN 'Monitor'
            WHEN 2 THEN 'Keyboard'
            WHEN 3 THEN 'Mouse'
            ELSE 'Headset'
        END,
        (@i % 5) + 1,
        CAST(((@i % 20) + 1) * 100000 AS DECIMAL(18,2)),
        CASE @i % 4
            WHEN 0 THEN 'Completed'
            WHEN 1 THEN 'Pending'
            WHEN 2 THEN 'Processing'
            ELSE 'Cancelled'
        END,
        DATEADD(DAY, -@i, SYSDATETIME()),
        DATEADD(DAY, -@i, SYSDATETIME())
    );

    SET @i += 1;
END;
GO
