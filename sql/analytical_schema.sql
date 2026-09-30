

CREATE SCHEMA IF NOT EXISTS analytics;
SET search_path TO analytics;


CREATE TABLE dim_date (
    date_key        INT PRIMARY KEY,
    full_date       DATE NOT NULL UNIQUE,
    day_of_month    SMALLINT NOT NULL,
    day_name        VARCHAR(10) NOT NULL,
    is_weekend      BOOLEAN NOT NULL,
    month_number    SMALLINT NOT NULL,
    month_name      VARCHAR(10) NOT NULL,
    quarter         SMALLINT NOT NULL,
    year            SMALLINT NOT NULL,
    year_month      INT NOT NULL
);

CREATE TABLE dim_customer (
    customer_key        SERIAL PRIMARY KEY,
    customer_id         BIGINT NOT NULL UNIQUE,
    customer_no         VARCHAR(20),
    first_name          VARCHAR(100),
    last_name            VARCHAR(100),
    email               VARCHAR(150),
    gender              VARCHAR(20),
    date_of_birth       DATE,
    registration_date   DATE,
    status              VARCHAR(20) NOT NULL,
    effective_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date            DATE,
    is_current          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE dim_location (
    location_key    SERIAL PRIMARY KEY,
    city_id         BIGINT NOT NULL UNIQUE,
    city_name       VARCHAR(100) NOT NULL,
    country_id      BIGINT NOT NULL,
    country_name    VARCHAR(100) NOT NULL,
    country_code    VARCHAR(5) NOT NULL
);

CREATE TABLE dim_subscription (
    subscription_key    SERIAL PRIMARY KEY,
    subscription_id     BIGINT NOT NULL UNIQUE,
    customer_id         BIGINT NOT NULL,
    plan_id              BIGINT NOT NULL,
    plan_name           VARCHAR(50) NOT NULL,
    monthly_fee         DECIMAL(10,2) NOT NULL,
    video_quality        VARCHAR(20),
    max_devices          INT,
    status               VARCHAR(20) NOT NULL,
    auto_renew           BOOLEAN
);

CREATE TABLE dim_content (
    content_key      SERIAL PRIMARY KEY,
    content_id       BIGINT NOT NULL UNIQUE,
    title            VARCHAR(255) NOT NULL,
    content_type     VARCHAR(50) NOT NULL,
    release_date     DATE,
    duration_minutes INT,
    language         VARCHAR(50),
    age_rating       VARCHAR(10)
);


CREATE TABLE dim_genre (
    genre_key       SERIAL PRIMARY KEY,
    genre_id        BIGINT NOT NULL UNIQUE,
    genre_name      VARCHAR(50) NOT NULL
);


CREATE TABLE dim_content_type (
    content_type_key   SERIAL PRIMARY KEY,
    content_type_id    BIGINT NOT NULL UNIQUE,
    content_type       VARCHAR(50) NOT NULL
);

CREATE TABLE dim_warehouse (
    warehouse_key    SERIAL PRIMARY KEY,
    warehouse_id     BIGINT NOT NULL UNIQUE,
    warehouse_name   VARCHAR(150) NOT NULL,
    city_id          BIGINT NOT NULL,
    city_name        VARCHAR(100) NOT NULL
);

CREATE TABLE dim_inventory (
    inventory_key    SERIAL PRIMARY KEY,
    inventory_id     BIGINT NOT NULL UNIQUE,
    content_id       BIGINT NOT NULL,
    barcode          VARCHAR(50),
    item_condition   VARCHAR(20),
    status           VARCHAR(20)
);


CREATE TABLE fact_customer_daily_activity (
    customer_activity_fact_id  BIGSERIAL PRIMARY KEY,
    customer_key           INT NOT NULL REFERENCES dim_customer(customer_key),
    date_key               INT NOT NULL REFERENCES dim_date(date_key),
    subscription_key       INT REFERENCES dim_subscription(subscription_key),
    location_key            INT REFERENCES dim_location(location_key),
    streaming_sessions       INT NOT NULL DEFAULT 0,
    total_streaming_duration INT NOT NULL DEFAULT 0,
    physical_rentals         INT NOT NULL DEFAULT 0,
    returned_items            INT NOT NULL DEFAULT 0,
    total_amount_spent       DECIMAL(12,2) NOT NULL DEFAULT 0,
    support_tickets_raised   INT NOT NULL DEFAULT 0,
    load_timestamp            TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_customer_daily UNIQUE (customer_key, date_key)
);


CREATE TABLE fact_content_monthly_performance (
    content_performance_fact_id BIGSERIAL PRIMARY KEY,
    content_key         INT NOT NULL REFERENCES dim_content(content_key),
    date_key             INT NOT NULL REFERENCES dim_date(date_key),
    genre_key             INT REFERENCES dim_genre(genre_key),
    content_type_key      INT REFERENCES dim_content_type(content_type_key),
    total_streams          INT NOT NULL DEFAULT 0,
    total_rental_count     INT NOT NULL DEFAULT 0,
    revenue_generated      DECIMAL(12,2) NOT NULL DEFAULT 0,
    avg_customer_rating    DECIMAL(3,2),
    wishlist_additions     INT NOT NULL DEFAULT 0,
    load_timestamp          TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_content_monthly UNIQUE (content_key, date_key)
);


CREATE TABLE fact_inventory_utilisation (
    inventory_utilisation_fact_id BIGSERIAL PRIMARY KEY,
    inventory_key       INT NOT NULL REFERENCES dim_inventory(inventory_key),
    date_key             INT NOT NULL REFERENCES dim_date(date_key),
    warehouse_key         INT REFERENCES dim_warehouse(warehouse_key),
    rentals                 INT NOT NULL DEFAULT 0,
    returns                  INT NOT NULL DEFAULT 0,
    days_available           INT NOT NULL DEFAULT 1,
    utilisation_percentage   DECIMAL(5,2) NOT NULL DEFAULT 0,
    load_timestamp            TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_inventory_daily UNIQUE (inventory_key, date_key)
);


CREATE TABLE stg_fact_customer_daily_activity (
    customer_id               BIGINT,
    activity_date              DATE,
    subscription_id            BIGINT,
    city_id                     BIGINT,
    streaming_sessions          INT,
    total_streaming_duration    INT,
    physical_rentals            INT,
    returned_items                INT,
    total_amount_spent          DECIMAL(12,2),
    support_tickets_raised       INT
);

CREATE TABLE stg_fact_content_monthly_performance (
    content_id           BIGINT,
    performance_month     DATE,
    genre_id               BIGINT,
    content_type_id        BIGINT,
    total_streams           INT,
    total_rental_count      INT,
    revenue_generated       DECIMAL(12,2),
    avg_customer_rating     DECIMAL(3,2),
    wishlist_additions      INT
);

CREATE TABLE stg_fact_inventory_utilisation (
    inventory_id      BIGINT,
    activity_date       DATE,
    warehouse_id         BIGINT,
    rentals               INT,
    returns                INT,
    days_available         INT,
    utilisation_percentage DECIMAL(5,2)
);


CREATE TABLE etl_error_log (
    error_id        BIGSERIAL PRIMARY KEY,
    pipeline_stage  VARCHAR(100) NOT NULL,
    source_table    VARCHAR(100),
    error_message   TEXT,
    record_payload  TEXT,
    logged_at       TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE etl_run_log (
    run_id          BIGSERIAL PRIMARY KEY,
    pipeline_name   VARCHAR(100) NOT NULL,
    started_at      TIMESTAMP NOT NULL,
    finished_at     TIMESTAMP,
    status          VARCHAR(20),
    rows_processed  INT,
    rows_rejected   INT
);


CREATE INDEX idx_fact_cda_date       ON fact_customer_daily_activity(date_key);
CREATE INDEX idx_fact_cmp_date       ON fact_content_monthly_performance(date_key);
CREATE INDEX idx_fact_inv_date       ON fact_inventory_utilisation(date_key);
CREATE INDEX idx_dim_customer_natid  ON dim_customer(customer_id);
CREATE INDEX idx_dim_content_natid   ON dim_content(content_id);
CREATE INDEX idx_dim_inventory_natid ON dim_inventory(inventory_id);


INSERT INTO dim_date (date_key, full_date, day_of_month, day_name, is_weekend,
                       month_number, month_name, quarter, year, year_month)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d,
    EXTRACT(DAY FROM d)::SMALLINT,
    TO_CHAR(d, 'Day'),
    EXTRACT(ISODOW FROM d) IN (6,7),
    EXTRACT(MONTH FROM d)::SMALLINT,
    TO_CHAR(d, 'Month'),
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(YEAR FROM d)::SMALLINT,
    TO_CHAR(d, 'YYYYMM')::INT
FROM generate_series('2024-01-01'::DATE, '2027-12-31'::DATE, INTERVAL '1 day') AS d;