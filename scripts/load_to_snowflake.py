"""
Load the PostgreSQL operational tables into Snowflake (FARM_OPS.RAW).

This is the "EL" step of ELT: copy each source table as-is into the RAW
schema, then dbt handles all transformation inside Snowflake.

Each run fully replaces the RAW tables (overwrite=True). The source data is
small, so a full refresh is simpler and safer than incremental logic, and
re-running is always idempotent.

Usage:
    python scripts/load_to_snowflake.py            # load every table
    python scripts/load_to_snowflake.py customers  # load selected tables

Environment variables (.env):
    Postgres:  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
    Snowflake: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PRIVATE_KEY_PATH,
               SNOWFLAKE_ROLE, SNOWFLAKE_WAREHOUSE, SNOWFLAKE_DATABASE
"""

import os
import sys

import pandas as pd
import snowflake.connector
from dotenv import load_dotenv
from snowflake.connector.pandas_tools import write_pandas

from db_connection import get_connection

load_dotenv()

# Load order does not matter for RAW (no FK constraints in Snowflake), but
# keeping dimensions first makes the log easier to read.
TABLES = [
    "customers",
    "suppliers",
    "workers",
    "products",
    "inventory",
    "incoming_orders_raw",
    "orders_cleaned",
    "order_items",
    "prep_lists",
    "deliveries",
    "worker_shifts",
]

RAW_SCHEMA = "RAW"


def snowflake_connection():
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        role=os.getenv("SNOWFLAKE_ROLE", "TRANSFORMER"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE", "FARM_WH"),
        database=os.getenv("SNOWFLAKE_DATABASE", "FARM_OPS"),
        schema=RAW_SCHEMA,
    )


def extract(pg_conn, table):
    """Read one Postgres table into a DataFrame with upper-case columns."""
    df = pd.read_sql(f"SELECT * FROM {table}", pg_conn)
    # Unquoted Snowflake identifiers are upper-case; matching that keeps
    # dbt source references case-insensitive.
    df.columns = [c.upper() for c in df.columns]
    return df


def load(sf_conn, table, df):
    success, _, nrows, _ = write_pandas(
        sf_conn,
        df,
        table_name=table.upper(),
        schema=RAW_SCHEMA,
        auto_create_table=True,
        overwrite=True,
        use_logical_type=True,  # keep timestamps as TIMESTAMP, not epoch numbers
    )
    if not success:
        raise RuntimeError(f"write_pandas reported failure for {table}")
    return nrows


def main(selected):
    tables = selected or TABLES
    unknown = sorted(set(tables) - set(TABLES))
    if unknown:
        sys.exit(f"Unknown table(s): {', '.join(unknown)}")

    pg_conn = get_connection()
    sf_conn = snowflake_connection()
    try:
        for table in tables:
            df = extract(pg_conn, table)
            nrows = load(sf_conn, table, df)
            print(f"{table:<22} {nrows:>6} rows -> {RAW_SCHEMA}.{table.upper()}")
    finally:
        pg_conn.close()
        sf_conn.close()


if __name__ == "__main__":
    main(sys.argv[1:])
