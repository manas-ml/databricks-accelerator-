"""
Delta Live Tables — Gold Pipeline
Reads from Silver DLT tables, produces business-ready aggregations.
"""
import dlt
from pyspark.sql import functions as F


# ---------------------------------------------------------------------------
# Gold: daily event summary
# ---------------------------------------------------------------------------
@dlt.table(
    name="gold_daily_event_summary",
    comment="Daily aggregated event metrics — business-ready for BI dashboards",
    table_properties={
        "quality": "gold",
        "pipelines.autoOptimize.managed": "true",
    },
    partition_cols=["event_date"],
)
def gold_daily_event_summary():
    return (
        dlt.read("silver_events")
        .groupBy("event_date")
        .agg(
            F.count("*").alias("total_events"),
            F.countDistinct("id").alias("unique_events"),
            F.countDistinct("customer_id").alias("unique_customers"),
            F.sum("amount").alias("total_amount"),
            F.avg("amount").alias("avg_amount"),
            F.max("amount").alias("max_amount"),
        )
        .withColumn("_gold_computed_at", F.current_timestamp())
    )


# ---------------------------------------------------------------------------
# Gold: customer 360 view
# ---------------------------------------------------------------------------
@dlt.table(
    name="gold_customer_360",
    comment="Customer 360 — joined events and customer profile",
    table_properties={
        "quality": "gold",
        "delta.enableChangeDataFeed": "true",
    },
)
def gold_customer_360():
    events = dlt.read("silver_events")
    customers = dlt.read("silver_customers")

    return (
        events
        .join(customers, on="customer_id", how="left")
        .groupBy("customer_id", "full_name", "email")
        .agg(
            F.count("id").alias("total_events"),
            F.sum("amount").alias("total_spend"),
            F.min("event_ts").alias("first_event_ts"),
            F.max("event_ts").alias("last_event_ts"),
            F.datediff(F.current_date(), F.max(F.to_date("event_ts"))).alias("days_since_last_event"),
        )
        .withColumn("customer_tier",
            F.when(F.col("total_spend") > 10000, "platinum")
            .when(F.col("total_spend") > 1000, "gold")
            .when(F.col("total_spend") > 100, "silver")
            .otherwise("bronze")
        )
        .withColumn("_gold_computed_at", F.current_timestamp())
    )
