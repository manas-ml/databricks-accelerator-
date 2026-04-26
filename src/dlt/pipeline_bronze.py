"""
Delta Live Tables — Bronze Pipeline
Ingests raw files from cloud storage using Auto Loader.
Configure via DLT pipeline parameters: catalog, bronze_schema, bronze_source, checkpoint_path.
"""
import dlt
from pyspark.sql import functions as F
from pyspark.sql.types import StructType

# Pipeline configuration (set in Terraform databricks_pipeline resource)
catalog = spark.conf.get("catalog", "accel_dev")
bronze_schema = spark.conf.get("bronze_schema", "bronze")
bronze_source = spark.conf.get("bronze_source", "")
checkpoint_base = spark.conf.get("checkpoint_path", "")


def _autoloader_source(source_format: str, source_path: str, schema_path: str):
    return (
        spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", source_format)
        .option("cloudFiles.schemaLocation", schema_path)
        .option("cloudFiles.inferColumnTypes", "true")
        .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
        .option("recursiveFileLookup", "true")
        .load(source_path)
    )


# ---------------------------------------------------------------------------
# Bronze: raw events
# ---------------------------------------------------------------------------
@dlt.table(
    name="bronze_events",
    comment="Raw events ingested from cloud storage via Auto Loader",
    table_properties={
        "quality": "bronze",
        "pipelines.autoOptimize.managed": "true",
    },
)
@dlt.expect_or_drop("valid_id", "id IS NOT NULL")
@dlt.expect("valid_event_ts", "event_ts IS NOT NULL")
def bronze_events():
    return (
        _autoloader_source(
            source_format="json",
            source_path=f"{bronze_source}/events/",
            schema_path=f"{checkpoint_base}/_schema/events",
        )
        .withColumn("_load_ts", F.current_timestamp())
        .withColumn("_source", F.lit("events"))
        .withColumn("_load_date", F.current_date())
        .withColumn("_ingest_file", F.input_file_name())
    )


# ---------------------------------------------------------------------------
# Bronze: raw customers
# ---------------------------------------------------------------------------
@dlt.table(
    name="bronze_customers",
    comment="Raw customer records from cloud storage",
    table_properties={"quality": "bronze"},
)
@dlt.expect_or_drop("valid_customer_id", "customer_id IS NOT NULL")
def bronze_customers():
    return (
        _autoloader_source(
            source_format="json",
            source_path=f"{bronze_source}/customers/",
            schema_path=f"{checkpoint_base}/_schema/customers",
        )
        .withColumn("_load_ts", F.current_timestamp())
        .withColumn("_source", F.lit("customers"))
        .withColumn("_load_date", F.current_date())
    )
