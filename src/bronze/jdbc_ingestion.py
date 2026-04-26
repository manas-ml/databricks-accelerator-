# Databricks notebook source
# Bronze layer: JDBC source ingestion template
# Full or incremental load from relational databases into Bronze Delta tables

# COMMAND ----------
dbutils.widgets.text("catalog", "accel_dev")
dbutils.widgets.text("bronze_schema", "bronze")
dbutils.widgets.text("target_table", "")
dbutils.widgets.text("jdbc_url_secret_key", "jdbc-url")
dbutils.widgets.text("jdbc_user_secret_key", "jdbc-user")
dbutils.widgets.text("jdbc_password_secret_key", "jdbc-password")
dbutils.widgets.text("source_table", "")
dbutils.widgets.text("watermark_column", "updated_at")
dbutils.widgets.text("watermark_value", "1970-01-01")
dbutils.widgets.text("load_mode", "incremental")   # full | incremental
dbutils.widgets.text("secret_scope", "accel-dev")

# COMMAND ----------
import sys
sys.path.insert(0, "/Workspace/Shared/accel")

from shared.config import load_config
from shared.logger import PipelineLogger
from shared.delta_utils import add_audit_columns, upsert_delta
import time

config = load_config(spark)
catalog = dbutils.widgets.get("catalog") or config.catalog
bronze_schema = dbutils.widgets.get("bronze_schema")
target_table_name = dbutils.widgets.get("target_table")
source_table = dbutils.widgets.get("source_table")
watermark_col = dbutils.widgets.get("watermark_column")
watermark_val = dbutils.widgets.get("watermark_value")
load_mode = dbutils.widgets.get("load_mode")
secret_scope = dbutils.widgets.get("secret_scope") or config.secret_scope
target_table = f"{catalog}.{bronze_schema}.{target_table_name}"

jdbc_url = dbutils.secrets.get(scope=secret_scope, key=dbutils.widgets.get("jdbc_url_secret_key"))
jdbc_user = dbutils.secrets.get(scope=secret_scope, key=dbutils.widgets.get("jdbc_user_secret_key"))
jdbc_password = dbutils.secrets.get(scope=secret_scope, key=dbutils.widgets.get("jdbc_password_secret_key"))

logger = PipelineLogger(
    pipeline_name=f"bronze.jdbc.{target_table_name}",
    layer="bronze",
    catalog=catalog,
    spark=spark,
)

# COMMAND ----------
logger.info("Starting JDBC ingestion", source=source_table, mode=load_mode)
start_ts = time.perf_counter()

# COMMAND ----------
query = source_table
if load_mode == "incremental":
    query = f"(SELECT * FROM {source_table} WHERE {watermark_col} > '{watermark_val}') t"

source_df = (
    spark.read
    .format("jdbc")
    .option("url", jdbc_url)
    .option("dbtable", query)
    .option("user", jdbc_user)
    .option("password", jdbc_password)
    .option("fetchsize", "10000")
    .load()
)

# COMMAND ----------
enriched_df = add_audit_columns(source_df, source_table)
rows_read = enriched_df.count()

# COMMAND ----------
# Write to bronze — append for full load; merge for incremental
if load_mode == "full":
    enriched_df.write.format("delta").mode("overwrite").saveAsTable(target_table)
    rows_written = rows_read
else:
    rows_written = upsert_delta(
        df=enriched_df,
        target_table=target_table,
        merge_keys=["id"],
    )

# COMMAND ----------
elapsed = time.perf_counter() - start_ts
logger.log_metrics(rows_read=rows_read, rows_written=rows_written, duration_seconds=elapsed)
logger.flush_to_delta()
