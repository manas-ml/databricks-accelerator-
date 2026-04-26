# Databricks notebook source
# Silver layer: Enrichment template
# Joins with lookup/reference tables, derives business columns, writes back to Silver

# COMMAND ----------
dbutils.widgets.text("catalog", "accel_dev")
dbutils.widgets.text("silver_schema", "silver")
dbutils.widgets.text("source_table", "")
dbutils.widgets.text("lookup_table", "")
dbutils.widgets.text("target_table", "")
dbutils.widgets.text("join_key", "")
dbutils.widgets.text("environment", "dev")

# COMMAND ----------
import sys
sys.path.insert(0, "/Workspace/Shared/accel")

from shared.config import load_config
from shared.logger import PipelineLogger
from shared.delta_utils import upsert_delta
from pyspark.sql import functions as F
import time

config = load_config(spark)
catalog = dbutils.widgets.get("catalog") or config.catalog
silver_schema = dbutils.widgets.get("silver_schema")
source_table = f"{catalog}.{silver_schema}.{dbutils.widgets.get('source_table')}"
lookup_table_name = dbutils.widgets.get("lookup_table")
target_table = f"{catalog}.{silver_schema}.{dbutils.widgets.get('target_table')}"
join_key = dbutils.widgets.get("join_key")

logger = PipelineLogger(
    pipeline_name=f"silver.enrich.{dbutils.widgets.get('target_table')}",
    layer="silver",
    catalog=catalog,
    spark=spark,
)

# COMMAND ----------
start_ts = time.perf_counter()
logger.info("Reading source", table=source_table)

source_df = spark.table(source_table)
rows_read = source_df.count()

# COMMAND ----------
# Join with lookup table if specified
enriched_df = source_df
if lookup_table_name:
    full_lookup = f"{catalog}.{silver_schema}.{lookup_table_name}"
    lookup_df = spark.table(full_lookup).select(join_key, *[
        c for c in spark.table(full_lookup).columns if c != join_key
    ])
    enriched_df = source_df.join(F.broadcast(lookup_df), on=join_key, how="left")
    logger.info("Joined with lookup", lookup=full_lookup)

# Derive enrichment columns — extend this section per domain
enriched_df = enriched_df.withColumn(
    "_enriched_at", F.current_timestamp()
)

# COMMAND ----------
rows_written = upsert_delta(
    df=enriched_df,
    target_table=target_table,
    merge_keys=[join_key] if join_key else ["id"],
)

# COMMAND ----------
elapsed = time.perf_counter() - start_ts
logger.log_metrics(rows_read=rows_read, rows_written=rows_written, duration_seconds=elapsed)
logger.flush_to_delta()
