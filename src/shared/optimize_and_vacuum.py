# Databricks notebook source
# Maintenance notebook: OPTIMIZE + VACUUM all tables in a given schema

# COMMAND ----------
dbutils.widgets.text("catalog", "accel_dev")
dbutils.widgets.text("schema", "gold")
dbutils.widgets.text("retain_hours", "168")
dbutils.widgets.text("environment", "dev")

# COMMAND ----------
import sys
sys.path.insert(0, "/Workspace/Shared/accel")

from shared.logger import PipelineLogger
from shared.delta_utils import optimize_and_vacuum
import time

catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")
retain_hours = int(dbutils.widgets.get("retain_hours"))
full_schema = f"{catalog}.{schema}"

logger = PipelineLogger(
    pipeline_name=f"maintenance.optimize.{schema}",
    layer=schema,
    catalog=catalog,
    spark=spark,
)

# COMMAND ----------
tables = [row.tableName for row in spark.sql(f"SHOW TABLES IN {full_schema}").collect()]
logger.info(f"Starting OPTIMIZE+VACUUM", schema=full_schema, table_count=len(tables))

start_ts = time.perf_counter()
for table in tables:
    full_table = f"{full_schema}.{table}"
    try:
        optimize_and_vacuum(full_table, spark, retain_hours=retain_hours)
        logger.info("Optimized and vacuumed", table=full_table)
    except Exception as e:
        logger.warn("Failed to optimize", table=full_table, error=str(e))

elapsed = time.perf_counter() - start_ts
logger.info(f"Maintenance complete", duration_seconds=round(elapsed, 2), tables=len(tables))
logger.flush_to_delta()
