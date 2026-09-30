# ABC Hub ETL Pipeline

Apache NiFi 2.10.0 and PostgreSQL project that loads operational data into an analytical star schema.

| Scenario | Grain | Fact table |
|---|---|---|
| Customer Daily Activity | Customer per day | `fact_customer_daily_activity` |
| Content Monthly Performance | Content per month | `fact_content_monthly_performance` |
| Inventory Utilisation | Inventory item per day | `fact_inventory_utilisation` |

## Package contents

Three NiFi flow exports, project documentation, scenario SQL extracted from the notes, `.gitignore`, an example database configuration, and instructions for data and screenshots.

## Database schemas and remaining additions

Both supplied database schema scripts are included under `sql/`. The analytical schema was supplied as pasted SQL text and saved as `analytical_schema.sql`. Add your verification screenshots and obtain the original source datasets separately.

Run the operational script only against a dedicated empty project database: it drops and recreates the `public` schema. The analytical script creates tables and is intended for a fresh analytical database.

## Setup

1. Install Apache NiFi 2.10.0 and PostgreSQL. The original PostgreSQL version is not recorded in the notes.
2. Create `abc_hub_operational` and `abc_hub_analytical` and apply their original schema scripts. Analytical tables use the `analytics` schema.
3. Import source CSV files into the operational database in the dependency order in `docs/project_documentation.md`.
4. Configure the PostgreSQL JDBC driver and root-canvas controller services `DBCP_Operational` and `DBCP_Analytical` with your local connection details. The example configuration is a reference template; NiFi does not read it automatically.
5. Import the JSON flow definitions from `nifi/`. Resolve controller-service references and check processor configuration before starting.
6. Follow the notes for dimension loading, extraction, staging, fact merging, and validation. Standalone SQL files contain statements for different databases; execute each in its intended database and substitute NiFi expression placeholders when running manually.

## Recorded results

The supplied notes report 58,021 customer daily activity rows, 7,099 content monthly performance rows, and 11,951 inventory utilisation rows. These are historical results; the pipelines were not rerun while making this package. The notes describe data-quality rules and idempotency verification.

## Publishing

Review exports and notes for private endpoints and credentials. Set database passwords locally. Add screenshots and document dataset access before describing the repository as fully reproducible. Check redistribution rights before adding source datasets.
