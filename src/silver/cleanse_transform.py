# Databricks notebook source
# Silver layer: Cleansing and deduplication template
# Reads from Bronze, applies quality rules, deduplicates, writes to Silver

# COMMAND ----------
dbutils.widgets.text("catalog", "accel_dev")
dbutils.widgets.text("bronze_schema", "bronze")
dbutils.widgets.text("silver_schema", "silver")
dbutils.widgets.text("source_table", "")
dbutils.widgets.text("target_table", "")
dbutils.widgets.text("dedup_keys", "id")
dbutils.widgets.text("order_by_col", "updated_at")
dbutils.widgets.text("environment", "dev")

# COMMAND ----------
import sys
sys.path.insert(0, "/Workspace/Shared/accel")

from shared.config import load_config
from shared.logger import PipelineLogger
from shared.delta_utils import upsert_delta
from shared.quality.expectations import not_null, unique, run_suite, assert_suite
from functools import partial
from pyspark.sql import functions as F
from pyspark.sql.window import Window
import time

config = load_config(spark)
catalog = dbutils.widgets.get("catalog") or config.catalog
bronze_schema = dbutils.widgets.get("bronze_schema")
silver_schema = dbutils.widgets.get("silver_schema")
source_table = f"{catalog}.{bronze_schema}.{dbutils.widgets.get('source_table')}"
target_table = f"{catalog}.{silver_schema}.{dbutils.widgets.get('target_table')}"
dedup_keys = dbutils.widgets.get("dedup_keys").split(",")
order_col = dbutils.widgets.get("order_by_col")

logger = PipelineLogger(
    pipeline_name=f"silver.cleanse.{dbutils.widgets.get('target_table')}",
    layer="silver",
    catalog=catalog,
    spark=spark,
)

# COMMAND ----------
logger.info("Reading from bronze", source=source_table)
start_ts = time.perf_counter()

raw_df = spark.table(source_table)
rows_read = raw_df.count()

# COMMAND ----------
# Step 1: Drop rows with null primary keys
clean_df = raw_df.dropna(subset=dedup_keys)

# Step 2: Cast and standardize types (extend this per schema)
# Example: trim string columns, standardize timestamps
str_cols = [f.name for f in clean_df.schema.fields if str(f.dataType) == "StringType()"]
for col in str_cols:
    clean_df = clean_df.withColumn(col, F.trim(F.col(col)))

# Step 3: Deduplicate — keep the latest record per dedup_keys
window = Window.partitionBy(*dedup_keys).orderBy(F.col(order_col).desc())
dedup_df = (
    clean_df
    .withColumn("_row_rank", F.row_number().over(window))
    .filter(F.col("_row_rank") == 1)
    .drop("_row_rank")
)

# COMMAND ----------
# Data quality checks
dq_results = run_suite(
    dedup_df,
    checks=[partial(not_null, column=k) for k in dedup_keys],
    table_name=target_table,
)
assert_suite(dq_results, raise_on_failure=True)

# COMMAND ----------
rows_written = upsert_delta(
    df=dedup_df,
    target_table=target_table,
    merge_keys=dedup_keys,
)

# COMMAND ----------
elapsed = time.perf_counter() - start_ts
logger.log_metrics(rows_read=rows_read, rows_written=rows_written, duration_seconds=elapsed)
logger.flush_to_delta()
logger.info("Silver cleanse complete", source=source_table, target=target_table)
