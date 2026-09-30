# NYC Taxi - Data Pipeline

An end-to-end data pipeline for [NYC taxi trip data](https://github.com/DataTalksClub/nyc-tlc-data): ingest raw trips, orchestrate loads, and transform them in a data warehouse.

**Stack:** Docker · PostgreSQL · pgAdmin · Kestra · BigQuery · dbt

## Project structure

```
pipeline/    Docker Compose stack (Postgres, pgAdmin, Kestra) and the Python ingestion script
taxi_dbt/    dbt project that transforms the taxi data in BigQuery
```

## Getting started

### 1. Start the services

```bash
cd pipeline
cp .env.example .env   # then fill in your own passwords
docker compose up -d
```

| Service  | URL                   |
|----------|-----------------------|
| Kestra   | http://localhost:8080 |
| pgAdmin  | http://localhost:8085 |
| Postgres | `localhost:5432`      |

### 2. Ingest data into Postgres

```bash
cd pipeline
uv run python ingest_data.py --dataset yellow --year 2021 --month 1
```

Run `uv run python ingest_data.py --help` for all options (connection settings, target table, chunk size).

### 3. Transform with dbt

Needs a BigQuery profile in `~/.dbt/profiles.yml` that points to a service-account key kept outside the repo.

```bash
cd taxi_dbt
dbt debug   # check the connection
dbt run     # build the models
```

## Credentials

Secrets are never committed. Local passwords go in `pipeline/.env` (gitignored), and the GCP service-account key is kept outside the repository.
