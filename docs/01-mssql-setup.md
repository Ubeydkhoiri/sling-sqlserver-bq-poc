# 1. Create the SQL Server source database

This guide starts a local SQL Server 2022 Developer container, creates the `SlingPOC` database, and loads two sample tables with 50 rows each.

## Prerequisites

- Docker Desktop installed and running
- `docker` and `docker compose` available in Terminal

Check Docker:

```bash
docker --version
docker info
```

## 1. Create the project directories

Run this from the directory where you want the project to live. This creates the project in the **current directory**, not under your home directory.

```bash
mkdir -p sling-sqlserver-bq-poc/{docker,sql,docs,config,credentials,logs}
cd sling-sqlserver-bq-poc
```

If you have already cloned or created the repository, simply `cd` into its root.

## 2. Configure the SQL Server password

Create a local `.env` file in the project root:

```bash
cat > .env <<'EOF'
MSSQL_SA_PASSWORD=YourStrong!Passw0rd123
EOF

chmod 600 .env
```

Replace the example password if required. SQL Server enforces password complexity. Keep this file private and do not commit it.

## 3. Start SQL Server with Docker Compose

The Compose file is [`../docker/docker-compose.yml`](../docker/docker-compose.yml).

From the project root:

```bash
docker compose --env-file .env -f docker/docker-compose.yml up -d
```

Check the container:

```bash
docker ps
docker logs -f sling-poc-sqlserver
```

Wait until SQL Server reports that it is ready for client connections. Press `Ctrl+C` to stop following the logs; the container continues running.

### SQL Server container details

| Setting | Value |
|---|---|
| Image | `mcr.microsoft.com/mssql/server:2022-latest` |
| Edition | Developer |
| Container | `sling-poc-sqlserver` |
| Host port | `1433` |
| Database | `SlingPOC` |
| Login | `sa` |

Developer Edition is intended for development and testing, not production use.

## 4. Check `sqlcmd` availability

Some SQL Server image versions do not include the `sqlcmd` utility. Check whether it is present:

```bash
docker exec sling-poc-sqlserver \
  bash -lc 'ls /opt/mssql-tools18/bin/sqlcmd'
```

If available, set the password variable in the current Terminal session:

```bash
export SA_PASSWORD="$(grep '^MSSQL_SA_PASSWORD=' .env | cut -d= -f2-)"
```

Test the connection:

```bash
docker exec sling-poc-sqlserver \
  /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C \
  -Q "SELECT @@VERSION"
```

If `sqlcmd` is not present in the image, use a SQL Server client such as DBeaver, or run a compatible Microsoft `mssql-tools` client container. Do not assume that every SQL Server image tag contains the client tools.

## 5. Create the database and tables

The table DDL is maintained in [`../sql/01_create_tables.sql`](../sql/01_create_tables.sql).

Create the database:

```bash
docker exec sling-poc-sqlserver \
  /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C \
  -Q "IF DB_ID('SlingPOC') IS NULL CREATE DATABASE SlingPOC;"
```

Execute the DDL:

```bash
docker exec -i sling-poc-sqlserver \
  /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C \
  -d master \
  < sql/01_create_tables.sql
```

The script creates:

### `dbo.customers`

| Column | Type | Purpose |
|---|---|---|
| `customer_id` | `INT` | Primary key |
| `customer_name` | `VARCHAR(100)` | Customer name |
| `email` | `VARCHAR(150)` | Email |
| `city` | `VARCHAR(50)` | City |
| `created_at` | `DATETIME2` | Creation timestamp |
| `updated_at` | `DATETIME2` | Last-update timestamp / incremental watermark |

### `dbo.orders`

| Column | Type | Purpose |
|---|---|---|
| `order_id` | `INT` | Primary key |
| `customer_id` | `INT` | Foreign key to customers |
| `order_date` | `DATE` | Order date |
| `product_name` | `VARCHAR(100)` | Product |
| `quantity` | `INT` | Quantity |
| `unit_price` | `DECIMAL(18,2)` | Unit price |
| `order_status` | `VARCHAR(30)` | Order status |
| `created_at` | `DATETIME2` | Creation timestamp |
| `updated_at` | `DATETIME2` | Last-update timestamp / incremental watermark |

## 6. Insert 50 sample rows into each table

The sample data is maintained in [`../sql/02_insert_dummy_data.sql`](../sql/02_insert_dummy_data.sql).

Execute it:

```bash
docker exec -i sling-poc-sqlserver \
  /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C \
  -d master \
  < sql/02_insert_dummy_data.sql
```

> Run this seed script only once on a fresh database. It inserts fixed primary keys and will fail with duplicate-key errors if executed again without clearing the tables.

## 7. Validate the source data

```bash
docker exec sling-poc-sqlserver \
  /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C \
  -d SlingPOC \
  -Q "
    SELECT 'customers' AS table_name, COUNT(*) AS total_rows
    FROM dbo.customers
    UNION ALL
    SELECT 'orders', COUNT(*)
    FROM dbo.orders;
  "
```

Expected result:

| Table | Rows |
|---|---:|
| `customers` | 50 |
| `orders` | 50 |
| **Total** | **100** |

## 8. Useful Docker commands

```bash
# List running containers
docker ps

# Follow SQL Server logs
docker logs -f sling-poc-sqlserver

# Stop the container but preserve its data volume
docker compose --env-file .env -f docker/docker-compose.yml down

# Start the container again
docker compose --env-file .env -f docker/docker-compose.yml up -d

# DESTRUCTIVE: remove the container and its named database volume
docker compose --env-file .env -f docker/docker-compose.yml down -v
```

SQL Server database files live in the Docker named volume `sqlserver_data`. They are not stored as a database file in the project directory.
