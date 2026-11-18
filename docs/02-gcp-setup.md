# 2. Prepare Google Cloud resources

This guide prepares the BigQuery destination, Cloud Storage staging bucket, and service account used by Sling.

## 1. Define the GCP variables

Set these variables once at the beginning of your Terminal session. Replace only the project ID placeholder.

```bash
export PROJECT_ID="<your-project_id>"
export REGION="asia-southeast2"
export BQ_DATASET="sling_poc"
export GCS_BUCKET="${PROJECT_ID}-sling-staging"
export SERVICE_ACCOUNT_ID="sling-poc-sa"
export SERVICE_ACCOUNT="${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
export KEY_FILE="$(pwd)/credentials/${SERVICE_ACCOUNT_ID}.json"
```

For example, if `PROJECT_ID=prj-sling-poc`, the bucket name becomes `prj-sling-poc-sling-staging`.

The bucket name must be globally unique. If it is already taken, change `GCS_BUCKET` to another globally unique name and use that variable in the Sling connection setup.

> These are shell variables. They are available in the current Terminal session. If you open a new Terminal, define them again or put non-secret values in a local environment file.

## 2. Authenticate and select the project

```bash
gcloud auth login
gcloud config set project "$PROJECT_ID"
gcloud config get-value project
```

Confirm that the active project is the intended project before creating resources.

## 3. Enable required APIs

```bash
gcloud services enable \
  bigquery.googleapis.com \
  bigqueryconnection.googleapis.com \
  storage.googleapis.com \
  --project="$PROJECT_ID"
```

## 4. Create the BigQuery dataset

```bash
bq --location="$REGION" mk \
  --dataset \
  "${PROJECT_ID}:${BQ_DATASET}"
```

Validate:

```bash
bq show "${PROJECT_ID}:${BQ_DATASET}"
```

## 5. Create the Cloud Storage staging bucket

Check whether the bucket exists and whether you have access:

```bash
gcloud storage buckets describe "gs://${GCS_BUCKET}"
```

If it does not exist and the name is available, create it:

```bash
gcloud storage buckets create "gs://${GCS_BUCKET}" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --uniform-bucket-level-access
```

Validate:

```bash
gcloud storage buckets describe "gs://${GCS_BUCKET}"
```

The bucket is used by Sling as temporary staging for BigQuery loads.

## 6. Create a service account

```bash
gcloud iam service-accounts create "$SERVICE_ACCOUNT_ID" \
  --project="$PROJECT_ID" \
  --display-name="Sling POC Service Account"
```

The service account email is held in `$SERVICE_ACCOUNT`.

## 7. Grant permissions

For this POC, grant BigQuery data editing and job creation permissions at project level:

```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/bigquery.jobUser"
```

Grant access to the staging bucket:

```bash
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/storage.objectAdmin"
```

For production, scope permissions as narrowly as possible, such as granting BigQuery data access on the required dataset rather than the whole project.

## 8. Create a service-account key for local POC use

Create the credentials directory if it does not exist:

```bash
mkdir -p credentials
```

Create the key:

```bash
gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account="$SERVICE_ACCOUNT" \
  --project="$PROJECT_ID"
```

Restrict local file permissions:

```bash
chmod 600 "$KEY_FILE"
ls -l "$KEY_FILE"
```

> **Security:** Never commit the service-account JSON key to Git or share it. Keep `credentials/` out of version control. For production, prefer keyless authentication where possible.

## 9. Resource summary

| Resource | Value |
|---|---|
| Project | `$PROJECT_ID` |
| Region | `$REGION` (`asia-southeast2`) |
| BigQuery dataset | `$BQ_DATASET` (`sling_poc`) |
| GCS bucket | `$GCS_BUCKET` (`${PROJECT_ID}-sling-staging`) |
| Service account | `$SERVICE_ACCOUNT` |
| Key file | `$KEY_FILE` |

Continue to [Configure Sling and run ingestion](03-sling-ingestion.md).
