# SQL Server to BigQuery with Sling

This repository contains a hands-on proof of concept (POC) for batch ingestion from Microsoft SQL Server to Google BigQuery using [Sling](https://slingdata.io/).

The setup runs SQL Server in Docker on macOS, creates two sample source tables, performs an initial load, and demonstrates incremental ingestion of new and updated records.

## POC workflow

```text
SQL Server (Docker)
  SlingPOC
  ├── dbo.customers
  └── dbo.orders
        |
        | Sling CLI
        v
Google Cloud Storage (temporary staging)
        |
        v
BigQuery
  <your-project_id>.sling_poc
  ├── customers
  └── orders
```

## Guides

Follow the guides in order:

1. [Create and prepare the SQL Server database](docs/01-mssql-setup.md)
2. [Prepare Google Cloud resources and service account](docs/02-gcp-setup.md)
3. [Configure Sling and run SQL Server-to-BigQuery ingestion](docs/03-sling-ingestion.md)

## Repository structure

```text
sling-sqlserver-bq-poc/
├── README.md
├── docs/
│   ├── 01-mssql-setup.md
│   ├── 02-gcp-setup.md
│   └── 03-sling-ingestion.md
├── docker/
│   └── docker-compose.yml
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_insert_dummy_data.sql
│   └── 03_incremental_test.sql
├── credentials/             # local service-account key; do not commit
└── .env                      # local SQL Server password; do not commit
```

The SQL scripts are kept separately in `sql/`; the guides link to the scripts instead of duplicating their contents. SQL Server's database files are stored in the Docker named volume `sqlserver_data`, not in this repository.

## Prerequisites

- macOS (Apple Silicon or Intel)
- Docker Desktop
- Sling CLI
- Google Cloud CLI (`gcloud`)
- A Google Cloud project with billing enabled and permission to enable APIs, create BigQuery/GCS resources, and manage IAM

Check the tools:

```bash
docker --version
docker info
sling --version
gcloud --version
uname -m
```

## Quick start

Create the project directory in your **current working directory**:

```bash
mkdir -p sling-sqlserver-bq-poc
cd sling-sqlserver-bq-poc
```

Then follow the three guides above. The POC uses these default resource names:

| Resource | Default |
|---|---|
| SQL Server container | `sling-poc-sqlserver` |
| SQL Server database | `SlingPOC` |
| SQL Server port | `1433` |
| Sling source connection | `MSSQL_POC` |
| Sling target connection | `BQ_POC` |
| BigQuery dataset | `sling_poc` |
| BigQuery location | `asia-southeast2` |
| GCS staging bucket | `<your-project_id>-sling-staging` |
| Service account ID | `sling-poc-sa` |

The project ID is intentionally a placeholder. Set your own `PROJECT_ID` in `docs/02-gcp-setup.md` and reuse the variables defined there.

## Expected outcome

After the initial load, BigQuery should contain:

| Table | Initial rows |
|---|---:|
| `customers` | 50 |
| `orders` | 50 |

After running the incremental test script and the incremental Sling job:

| Table | Expected rows |
|---|---:|
| `customers` | 52 |
| `orders` | 51 |

The test also updates customer `10` and order `1001`. Their existing BigQuery rows should be updated rather than duplicated.

## Important notes

- The incremental example uses `updated_at` as a watermark and primary keys for matching records. Validate the exact checkpoint and merge behavior with the Sling version you install.
- Timestamp-watermark ingestion is not equivalent to database CDC. Late-arriving records, equal timestamps, and hard deletes require additional handling.
- This is a local POC, not a production deployment. For production, consider keyless authentication, least-privilege IAM, managed orchestration, monitoring, retries, and a tested delete-capture strategy.
- Never commit `.env`, service-account JSON keys, or other secrets.
