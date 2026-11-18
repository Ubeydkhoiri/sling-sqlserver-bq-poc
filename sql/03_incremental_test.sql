USE SlingPOC;
GO

-- Update an existing customer.
UPDATE dbo.customers
SET
    city = 'Bogor',
    updated_at = SYSDATETIME()
WHERE customer_id = 10;
GO

WAITFOR DELAY '00:00:02';
GO

-- Insert two new customers.
INSERT INTO dbo.customers (
    customer_id, customer_name, email, city,
    created_at, updated_at
)
VALUES
(
    51, 'Customer 51', 'customer51@example.com',
    'Jakarta', SYSDATETIME(), SYSDATETIME()
),
(
    52, 'Customer 52', 'customer52@example.com',
    'Bekasi', SYSDATETIME(), SYSDATETIME()
);
GO

-- Update an existing order.
UPDATE dbo.orders
SET
    order_status = 'Completed',
    quantity = 3,
    updated_at = SYSDATETIME()
WHERE order_id = 1001;
GO

WAITFOR DELAY '00:00:02';
GO

-- Insert a new order.
INSERT INTO dbo.orders (
    order_id, customer_id, order_date, product_name,
    quantity, unit_price, order_status, created_at, updated_at
)
VALUES (
    1051, 51, CAST(GETDATE() AS DATE), 'Laptop',
    2, 15000000, 'Pending', SYSDATETIME(), SYSDATETIME()
);
GO
