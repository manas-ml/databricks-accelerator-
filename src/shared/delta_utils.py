"""
Delta Lake utility helpers: upsert (merge), schema evolution, optimize, vacuum.
"""
from typing import List, Optional
from pyspark.sql import DataFrame, SparkSession


def upsert_delta(
    df: DataFrame,
    target_table: str,
    merge_keys: List[str],
    update_cols: Optional[List[str]] = None,
    partition_cols: Optional[List[str]] = None,
) -> int:
    """
    Merge df into target_table using merge_keys.
    Creates the target table if it doesn't exist.
    Returns the number of rows written (inserted + updated).
    """
    from delta.tables import DeltaTable
    spark = df.sparkSession

    if not _table_exists(spark, target_table):
        writer = df.write.format("delta").mode("overwrite")
        if partition_cols:
            writer = writer.partitionBy(*partition_cols)
        writer.saveAsTable(target_table)
        return df.count()

    delta_table = DeltaTable.forName(spark, target_table)
    merge_condition = " AND ".join(
        [f"target.{k} = source.{k}" for k in merge_keys]
    )

    update_set = (
        {c: f"source.{c}" for c in update_cols}
        if update_cols
        else {c: f"source.{c}" for c in df.columns}
    )

    (
        delta_table.alias("target")
        .merge(df.alias("source"), merge_condition)
        .whenMatchedUpdate(set=update_set)
        .whenNotMatchedInsertAll()
        .execute()
    )

    metrics = delta_table.history(1).select("operationMetrics").first()[0]
    return int(metrics.get("numTargetRowsInserted", 0)) + int(
        metrics.get("numTargetRowsUpdated", 0)
    )


def optimize_and_vacuum(table: str, spark: SparkSession, retain_hours: int = 168):
    """Run OPTIMIZE + ZORDER on the table, then VACUUM."""
    spark.sql(f"OPTIMIZE {table}")
    spark.sql(f"VACUUM {table} RETAIN {retain_hours} HOURS")


def add_audit_columns(df: DataFrame, source_name: str) -> DataFrame:
    """Append standard audit metadata columns to a DataFrame."""
    from pyspark.sql import functions as F
    return (
        df
        .withColumn("_load_ts", F.current_timestamp())
        .withColumn("_source", F.lit(source_name))
        .withColumn("_load_date", F.current_date())
    )


def schema_to_ddl(df: DataFrame) -> str:
    """Return the DDL schema string for a DataFrame (useful for CREATE TABLE)."""
    return df.schema.simpleString()


def _table_exists(spark: SparkSession, table: str) -> bool:
    try:
        spark.table(table)
        return True
    except Exception:
        return False


def read_delta_stream(spark: SparkSession, table_or_path: str) -> DataFrame:
    """Read a Delta table as a streaming DataFrame (for Auto Loader or DLT use)."""
    return spark.readStream.format("delta").table(table_or_path)
