"""
Delta Live Tables — Silver Pipeline
Reads from Bronze DLT tables, applies cleansing, deduplication, and quality checks.
"""
import dlt
from pyspark.sql import functions as F
from pyspark.sql.window import Window


# ---------------------------------------------------------------------------
# Silver: cleansed events
# ---------------------------------------------------------------------------
@dlt.table(
    name="silver_events",
    comment="Cleansed and deduplicated events with validated fields",
    table_properties={
        "quality": "silver",
        "pipelines.autoOptimize.managed": "true",
        "delta.enableChangeDataFeed": "true",
    },
    partition_cols=["event_date"],
)
@dlt.expect_or_fail("no_null_id", "id IS NOT NULL")
@dlt.expect_or_fail("no_null_event_ts", "event_ts IS NOT NULL")
@dlt.expect("valid_amount", "amount >= 0")
def silver_events():
    window = Window.partitionBy("id").orderBy(F.col("event_ts").desc())
    return (
        dlt.read_stream("bronze_events")
        # Remove null PKs
        .filter(F.col("id").isNotNull())
        # Trim string columns
        .withColumn("status", F.trim(F.col("status")))
        # Deduplicate: keep latest per id
        .withColumn("_row_rank", F.row_number().over(window))
        .filter(F.col("_row_rank") == 1)
        .drop("_row_rank", "_ingest_file")
        # Add silver metadata
        .withColumn("event_date", F.to_date("event_ts"))
        .withColumn("_silver_ts", F.current_timestamp())
    )


# ---------------------------------------------------------------------------
# Silver: cleansed customers
# ---------------------------------------------------------------------------
@dlt.table(
    name="silver_customers",
    comment="Cleansed customer records",
    table_properties={
        "quality": "silver",
        "delta.enableChangeDataFeed": "true",
    },
)
@dlt.expect_or_fail("no_null_customer_id", "customer_id IS NOT NULL")
@dlt.expect("valid_email", "email RLIKE '^[^@]+@[^@]+\\.[^@]+$'")
def silver_customers():
    return (
        dlt.read("bronze_customers")
        .filter(F.col("customer_id").isNotNull())
        .withColumn("email", F.lower(F.trim(F.col("email"))))
        .withColumn("full_name", F.concat_ws(" ", F.col("first_name"), F.col("last_name")))
        .withColumn("_silver_ts", F.current_timestamp())
        .dropDuplicates(["customer_id"])
    )
