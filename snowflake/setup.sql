-- =========================================================================
-- Snowflake setup for Farm Operations Analytics
-- Run once as ACCOUNTADMIN (Snowsight worksheet).
--
-- Layout:
--   FARM_OPS.RAW        <- loaded by scripts/load_to_snowflake.py (Postgres copy)
--   FARM_OPS.ANALYTICS  <- built by dbt (staging views, marts tables)
--
-- Cost guardrails: one X-SMALL warehouse that suspends after 60s idle.
-- =========================================================================

USE ROLE ACCOUNTADMIN;

-- Compute
CREATE WAREHOUSE IF NOT EXISTS FARM_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- Storage
CREATE DATABASE IF NOT EXISTS FARM_OPS;
CREATE SCHEMA IF NOT EXISTS FARM_OPS.RAW;
CREATE SCHEMA IF NOT EXISTS FARM_OPS.ANALYTICS;

-- Least-privilege role for the loader and dbt
CREATE ROLE IF NOT EXISTS TRANSFORMER;
GRANT USAGE ON WAREHOUSE FARM_WH TO ROLE TRANSFORMER;
GRANT USAGE ON DATABASE FARM_OPS TO ROLE TRANSFORMER;
GRANT ALL ON SCHEMA FARM_OPS.RAW TO ROLE TRANSFORMER;
GRANT ALL ON SCHEMA FARM_OPS.ANALYTICS TO ROLE TRANSFORMER;
-- dbt creates per-target schemas (e.g. ANALYTICS_STAGING), so it needs CREATE SCHEMA
GRANT CREATE SCHEMA ON DATABASE FARM_OPS TO ROLE TRANSFORMER;

-- Service user for the loader, dbt and CI.
-- Snowflake is phasing out password-only logins, so this user signs in with a
-- key pair. Generate the keys locally first (see README "Snowflake + dbt"):
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_key.p8 -nocrypt
--   openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
-- Paste the public key body (without the BEGIN/END lines) below.
CREATE USER IF NOT EXISTS DBT_USER
  TYPE = SERVICE
  DEFAULT_ROLE = TRANSFORMER
  DEFAULT_WAREHOUSE = FARM_WH
  RSA_PUBLIC_KEY = '<paste-public-key-here>';
GRANT ROLE TRANSFORMER TO USER DBT_USER;

-- Let your own login use the role too (replace with your Snowflake username)
-- GRANT ROLE TRANSFORMER TO USER <YOUR_USERNAME>;

-- Optional: cap spend on the trial account
-- CREATE RESOURCE MONITOR farm_monitor WITH CREDIT_QUOTA = 20
--   TRIGGERS ON 90 PERCENT DO SUSPEND;
-- ALTER WAREHOUSE FARM_WH SET RESOURCE_MONITOR = farm_monitor;
