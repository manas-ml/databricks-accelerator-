# Databricks notebook source
# Gold layer: ML Feature Store write template
# Computes ML features from Silver tables and publishes to Databricks Feature Store

# COMMAND ----------
dbutils.widgets.text("catalog", "accel_dev")
dbutils.widgets.text("silver_schema", "silver")
dbutils.widgets.text("gold_schema", "gold")
dbutils.widgets.text("source_table", "")
dbutils.widgets.text("feature_table_name", "")
dbutils.widgets.text("primary_keys", "id")
dbutils.widgets.text("timestamp_col", "event_ts")
dbutils.widgets.text("environment", "dev")

# COMMAND ----------
import sys
sys.path.insert(0, "/Workspace/Shared/accel")

from shared.config import load_config
from shared.logger import PipelineLogger
from pyspark.sql import functions as F
import time

config = load_config(spark)
catalog = dbutils.widgets.get("catalog") or config.catalog
silver_schema = dbutils.widgets.get("silver_schema")
gold_schema = dbutils.widgets.get("gold_schema")
source_table = f"{catalog}.{silver_schema}.{dbutils.widgets.get('source_table')}"
feature_table = f"{catalog}.{gold_schema}.{dbutils.widgets.get('feature_table_name')}"
primary_keys = dbutils.widgets.get("primary_keys").split(",")
timestamp_col = dbutils.widgets.get("timestamp_col")

logger = PipelineLogger(
    pipeline_name=f"gold.feature_store.{dbutils.widgets.get('feature_table_name')}",
    layer="gold",
    catalog=catalog,
    spark=spark,
)

# COMMAND ----------
from databricks.feature_engineering import FeatureEngineeringClient

fe = FeatureEngineeringClient()
start_ts = time.perf_counter()

# COMMAND ----------
source_df = spark.table(source_table)
rows_read = source_df.count()

# Feature engineering — extend this per ML use case
features_df = (
    source_df
    .withColumn("days_since_first_event", F.datediff(F.current_date(), F.to_date(F.col(timestamp_col))))
    .withColumn("event_hour", F.hour(F.col(timestamp_col)))
    .withColumn("is_weekend", (F.dayofweek(F.col(timestamp_col)).isin([1, 7])).cast("integer"))
    .select(*primary_keys, timestamp_col, "days_since_first_event", "event_hour", "is_weekend")
)

# COMMAND ----------
# Write to Feature Store (creates table if it doesn't exist, merges if it does)
from databricks.feature_engineering import FeatureLookup
try:
    fe.create_table(
        name=feature_table,
        primary_keys=primary_keys,
        timestamp_keys=[timestamp_col],
        df=features_df,
        description=f"ML features computed from {source_table}",
    )
    logger.info("Feature table created", table=feature_table)
except Exception:
    fe.write_table(
        name=feature_table,
        df=features_df,
        mode="merge",
    )
    logger.info("Feature table updated", table=feature_table)

# COMMAND ----------
elapsed = time.perf_counter() - start_ts
logger.log_metrics(rows_read=rows_read, rows_written=features_df.count(), duration_seconds=elapsed)
logger.flush_to_delta()
