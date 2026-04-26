# Databricks notebook source
# Bronze layer: Auto Loader ingestion template
# Reads files from cloud storage (S3) incrementally and writes to Delta

# COMMAND ----------
# MAGIC %pip install --quiet databricks-sdk

# COMMAND ----------
dbutils.widgets.text("catalog", "accel_dev")
dbutils.widgets.text("bronze_schema", "bronze")
dbutils.widgets.text("source_path", "")
dbutils.widgets.text("source_format", "json")
dbutils.widgets.text("target_table", "")
dbutils.widgets.text("checkpoint_path", "")
dbutils.widgets.text("merge_keys", "id")
dbutils.widgets.text("environment", "dev")
dbutils.widgets.text("secret_scope", "accel-dev")

# COMMAND ----------
import sys
sys.path.insert(0, "/Workspace/Shared/accel")

from shared.config import load_config
from shared.logger import PipelineLogger
from shared.delta_utils import add_audit_columns, upsert_delta
from pyspark.sql import functions as F
import time

config = load_config(spark)
catalog = dbutils.widgets.get("catalog") or config.catalog
bronze_schema = dbutils.widgets.get("bronze_schema") or config.bronze_schema
source_path = dbutils.widgets.get("source_path")
source_format = dbutils.widgets.get("source_format")
target_table_name = dbutils.widgets.get("target_table")
checkpoint_path = dbutils.widgets.get("checkpoint_path")
merge_keys = dbutils.widgets.get("merge_keys").split(",")
target_table = f"{catalog}.{bronze_schema}.{target_table_name}"

logger = PipelineLogger(
    pipeline_name=f"bronze.{target_table_name}",
    layer="bronze",
    catalog=catalog,
    spark=spark,
)

# COMMAND ----------
logger.info("Starting Auto Loader ingestion", source_path=source_path, target=target_table)
start_ts = time.perf_counter()

# COMMAND ----------
# Auto Loader: reads new files incrementally, infers schema, handles schema evolution
raw_df = (
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", source_format)
    .option("cloudFiles.schemaLocation", f"{checkpoint_path}/_schema")
    .option("cloudFiles.inferColumnTypes", "true")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .option("recursiveFileLookup", "true")
    .load(source_path)
)

# COMMAND ----------
# Add audit metadata columns
enriched_df = (
    add_audit_columns(raw_df, source_path)
    .withColumn("_ingest_file", F.input_file_name())
)

# COMMAND ----------
# Stream writer: append mode for bronze (immutable raw records)
def write_batch(batch_df, batch_id):
    rows = batch_df.count()
    if rows == 0:
        return
    batch_df.write.format("delta").mode("append").saveAsTable(target_table)
    logger.info(f"Batch {batch_id} written", rows=rows, target=target_table)

query = (
    enriched_df
    .writeStream
    .foreachBatch(write_batch)
    .option("checkpointLocation", checkpoint_path)
    .trigger(availableNow=True)   # process all available files then stop
    .start()
)

query.awaitTermination()

# COMMAND ----------
elapsed = time.perf_counter() - start_ts
logger.log_metrics(rows_read=-1, rows_written=-1, duration_seconds=elapsed)
logger.flush_to_delta()
logger.info("Auto Loader ingestion complete", target=target_table)
