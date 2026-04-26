# Databricks notebook source
# Gold layer: Business aggregation template
# Reads from Silver, produces business-ready summary tables for BI/reporting

# COMMAND ----------
dbutils.widgets.text("catalog", "accel_dev")
dbutils.widgets.text("silver_schema", "silver")
dbutils.widgets.text("gold_schema", "gold")
dbutils.widgets.text("source_table", "")
dbutils.widgets.text("target_table", "")
dbutils.widgets.text("agg_date_col", "event_date")
dbutils.widgets.text("agg_partition_col", "event_date")
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
gold_schema = dbutils.widgets.get("gold_schema")
source_table = f"{catalog}.{silver_schema}.{dbutils.widgets.get('source_table')}"
target_table = f"{catalog}.{gold_schema}.{dbutils.widgets.get('target_table')}"
date_col = dbutils.widgets.get("agg_date_col")
partition_col = dbutils.widgets.get("agg_partition_col")

logger = PipelineLogger(
    pipeline_name=f"gold.aggregate.{dbutils.widgets.get('target_table')}",
    layer="gold",
    catalog=catalog,
    spark=spark,
)

# COMMAND ----------
start_ts = time.perf_counter()
logger.info("Reading silver", source=source_table)

silver_df = spark.table(source_table)
rows_read = silver_df.count()

# COMMAND ----------
# Daily aggregation — extend this per domain
agg_df = (
    silver_df
    .withColumn("agg_date", F.to_date(F.col(date_col)))
    .groupBy("agg_date")
    .agg(
        F.count("*").alias("record_count"),
        F.countDistinct("id").alias("unique_ids"),
        F.max(F.col("_load_ts")).alias("last_updated"),
    )
    .withColumn("_gold_computed_at", F.current_timestamp())
)

# COMMAND ----------
rows_written = upsert_delta(
    df=agg_df,
    target_table=target_table,
    merge_keys=["agg_date"],
    partition_cols=[partition_col] if partition_col else None,
)

# COMMAND ----------
elapsed = time.perf_counter() - start_ts
logger.log_metrics(rows_read=rows_read, rows_written=rows_written, duration_seconds=elapsed)
logger.flush_to_delta()
logger.info("Gold aggregation complete", target=target_table)
