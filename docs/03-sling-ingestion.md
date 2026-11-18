# 3. Configure Sling and ingest SQL Server data into BigQuery

This guide configures Sling connections, runs the initial full load, and demonstrates incremental ingestion for new and updated records.

Complete these guides first:

- [SQL Server setup](01-mssql-setup.md)
- [GCP setup](02-gcp-setup.md)

## 1. Set the environment variables

Open a Terminal at the repository root (`sling-sqlserver-bq-poc`).

Set the SQL Server password from your local `.env` file:

```bash
export SA_PASSWORD="$(grep '^MSSQL_SA_PASSWORD=' .env | cut -d= -f2-)"
```

Set the GCP variables again if this is a new Terminal session. Use the same values as in the GCP setup guide:

```bash
export PROJECT_ID="<your-project_id>"
export REGION="asia-southeast2"
export BQ_DATASET="sling_poc"
export GCS_BUCKET="${PROJECT_ID}-sling-staging"
export SERVICE_ACCOUNT_ID="sling-poc-sa"
export SERVICE_ACCOUNT="${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
export KEY_FILE="$(pwd)/credentials/${SERVICE_ACCOUNT_ID}.json"
```

## 2. Configure Sling connections

Create the SQL Server source connection:

```bash
sling conns set MSSQL_POC \
  type=sqlserver \
  host=localhost \
  port=1433 \
  user=sa \
  password="$SA_PASSWORD" \
  database=SlingPOC
```

Create the BigQuery target connection:

```bash
sling conns set BQ_POC \
  type=bigquery \
  project="$PROJECT_ID" \
  dataset="$BQ_DATASET" \
  gc_bucket="$GCS_BUCKET" \
  key_file="$KEY_FILE" \
  location="$REGION"
```

List and test both connections:

```bash
sling conns list
sling conns test MSSQL_POC
sling conns test BQ_POC
```

Both tests should succeed before running replication.

## 3. Initial full load

The initial-load configuration is [`../config/replication_initial.yaml`](../config/replication_initial.yaml):

```yaml
source: MSSQL_POC
target: BQ_POC

defaults:
  mode: full-refresh
  target_options:
    add_new_columns: true
    column_casing: snake

streams:
  dbo.customers:
    object: customers

  dbo.orders:
    object: orders
```

Run it from the repository root:

```bash
sling run -r config/replication_initial.yaml
```

The source-to-target mapping is:

| SQL Server | BigQuery |
|---|---|
| `SlingPOC.dbo.customers` | `<your-project_id>.sling_poc.customers` |
| `SlingPOC.dbo.orders` | `<your-project_id>.sling_poc.orders` |

> **Warning:** `full-refresh` refreshes/replaces destination table contents. Use this for the initial load, not as the daily incremental job.

### Validate the initial load

Run in BigQuery:

```sql
SELECT
  'customers' AS table_name,
  COUNT(*) AS total_rows
FROM `<your-project_id>.sling_poc.customers`

UNION ALL

SELECT
  'orders',
  COUNT(*)
FROM `<your-project_id>.sling_poc.orders`;
```

Expected: 50 rows in each table.

## 4. Configure incremental ingestion

The incremental configuration is [`../config/replication_incremental.yaml`](../config/replication_incremental.yaml):

```yaml
source: MSSQL_POC
target: BQ_POC

defaults:
  mode: incremental
  target_options:
    add_new_columns: true
    column_casing: snake

streams:
  dbo.customers:
    object: customers
    primary_key: [customer_id]
    update_key: updated_at

  dbo.orders:
    object: orders
    primary_key: [order_id]
    update_key: updated_at
```

The primary key identifies the destination record. The update key identifies the source timestamp used for incremental extraction/checkpointing. With a primary key and update key, this configuration is intended to support inserts and updates.

> **Important:** Verify the exact incremental behavior and state/checkpoint handling for your installed Sling version. A timestamp watermark is not a transaction log and is not equivalent to SQL Server CDC.

## 5. Simulate source changes

The test SQL is in [`../sql/03_incremental_test.sql`](../sql/03_incremental_test.sql).

It performs these changes:

| Table | Operation | Record |
|---|---|---|
| customers | Update city to `Bogor` | `customer_id = 10` |
| customers | Insert | `customer_id = 51` |
| customers | Insert | `customer_id = 52` |
| orders | Update quantity/status | `order_id = 1001` |
| orders | Insert | `order_id = 1051` |

Execute the test script:

```bash
docker exec -i sling-poc-sqlserver \
  /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C \
  -d master \
  < sql/03_incremental_test.sql
```

The script updates existing rows first and waits briefly before inserting new rows. This helps make the test timestamps progress in order.

## 6. Run incremental ingestion

```bash
sling run -r config/replication_incremental.yaml
```

### Expected row counts

| Table | Initial load | After incremental |
|---|---:|---:|
| customers | 50 | 52 |
| orders | 50 | 51 |
| **Total** | **100** | **103** |

### Validate the updated customer

```sql
SELECT customer_id, customer_name, city, updated_at
FROM `<your-project_id>.sling_poc.customers`
WHERE customer_id = 10;
```

Expected city: `Bogor`.

### Validate inserted customers

```sql
SELECT *
FROM `<your-project_id>.sling_poc.customers`
WHERE customer_id IN (51, 52);
```

Expected: two rows.

### Validate the updated order

```sql
SELECT order_id, customer_id, quantity, order_status, updated_at
FROM `<your-project_id>.sling_poc.orders`
WHERE order_id = 1001;
```

Expected: quantity `3`, status `Completed`.

### Validate the inserted order

```sql
SELECT *
FROM `<your-project_id>.sling_poc.orders`
WHERE order_id = 1051;
```

Expected: one row.

## 7. Test a second incremental run

Run the same job again without making more source changes:

```bash
sling run -r config/replication_incremental.yaml
```

Expected row counts should remain:

- customers: 52
- orders: 51

If counts increase, investigate the primary-key, update-key, replication mode, and target merge behavior.

## 8. Optional: run the job from a shell script

Create `run_incremental.sh` in the repository root:

```bash
#!/bin/bash

set -o pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/incremental_$(date +%Y%m%d).log"

mkdir -p "$LOG_DIR"
cd "$PROJECT_DIR" || exit 1

# Load local SQL Server password.
export SA_PASSWORD="$(grep '^MSSQL_SA_PASSWORD=' .env | cut -d= -f2-)"

echo "Ingestion started: $(date)" >> "$LOG_FILE"

sling run -r config/replication_incremental.yaml >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

echo "Ingestion finished: $(date)" >> "$LOG_FILE"
echo "Exit code: $EXIT_CODE" >> "$LOG_FILE"

exit "$EXIT_CODE"
```

Make it executable and test it:

```bash
chmod +x run_incremental.sh
./run_incremental.sh
```

Check the log:

```bash
tail -100 logs/incremental_$(date +%Y%m%d).log
```

For this script, the Sling connections must already have been configured for the same macOS user.

## 9. Optional: schedule with macOS cron

Edit the crontab:

```bash
crontab -e
```

Add a daily 02:00 schedule, replacing the path with the absolute path to your repository:

```cron
0 2 * * * /absolute/path/to/sling-sqlserver-bq-poc/run_incremental.sh
```

Check the schedule:

```bash
crontab -l
```

The Mac must be awake, online, and running Docker/SQL Server at the scheduled time. For production, use a managed scheduler and execution environment instead of a laptop.

## 10. Incremental ingestion considerations

This POC demonstrates a simple batch watermark pattern. Consider these limitations before using it in production:

1. **Hard deletes:** `updated_at` does not capture a row that has been physically deleted. Evaluate SQL Server CDC or Change Tracking if deletes must be replicated.
2. **Late-arriving rows:** A row inserted later with an old `updated_at` may be missed by a strict watermark.
3. **Timestamp ties:** Multiple changes can share the same timestamp. Consider an overlap window, a composite watermark, or CDC.
4. **Checkpoint and recovery:** Test where Sling stores state and how it behaves after failed runs, retries, and configuration changes.
5. **Idempotency:** Verify that rerunning the job does not duplicate target records.
6. **Schema changes:** Test added, renamed, and changed columns.
7. **Security:** Do not commit credentials. Prefer keyless authentication and least-privilege IAM in production.
8. **Observability:** Record job status, duration, row counts, errors, and source/target reconciliation.

## References

- [Sling documentation](https://docs.slingdata.io/)
- [Sling replication modes](https://docs.slingdata.io/concepts/replication/modes)
- [Sling replication structure](https://docs.slingdata.io/concepts/replication/structure)
- [Sling CLI connections](https://docs.slingdata.io/sling-cli/environment)
- [Sling BigQuery connection](https://docs.slingdata.io/connections/database-connections/bigquery)
- [Microsoft SQL Server Linux containers](https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker)
- [BigQuery documentation](https://cloud.google.com/bigquery/docs)
- [Cloud Storage documentation](https://cloud.google.com/storage/docs)
