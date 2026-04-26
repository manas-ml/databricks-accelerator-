"""
Environment and catalog configuration loader.
Reads from Databricks widgets (notebook) or environment variables (job context).
"""
import os
from dataclasses import dataclass
from typing import Optional

try:
    from pyspark.sql import SparkSession
    _spark_available = True
except ImportError:
    _spark_available = False


@dataclass
class PlatformConfig:
    environment: str
    catalog: str
    bronze_schema: str
    silver_schema: str
    gold_schema: str
    sandbox_schema: str
    audit_schema: str
    secret_scope: str
    bronze_path: str
    silver_path: str
    gold_path: str
    checkpoint_path: str


def _get_widget_or_env(name: str, default: Optional[str] = None) -> Optional[str]:
    """Read from Databricks widget first, fall back to env var, then default."""
    if _spark_available:
        try:
            from pyspark.dbutils import DBUtils
            spark = SparkSession.getActiveSession()
            if spark:
                dbutils = DBUtils(spark)
                val = dbutils.widgets.get(name)
                if val:
                    return val
        except Exception:
            pass
    return os.environ.get(name, default)


def load_config(spark=None) -> PlatformConfig:
    """Load platform configuration from widgets/env vars."""
    env = _get_widget_or_env("environment", "dev")
    project = _get_widget_or_env("project", "accel")
    catalog = _get_widget_or_env("catalog", f"{project}_{env}")

    return PlatformConfig(
        environment=env,
        catalog=catalog,
        bronze_schema=_get_widget_or_env("bronze_schema", "bronze"),
        silver_schema=_get_widget_or_env("silver_schema", "silver"),
        gold_schema=_get_widget_or_env("gold_schema", "gold"),
        sandbox_schema=_get_widget_or_env("sandbox_schema", "sandbox"),
        audit_schema=_get_widget_or_env("audit_schema", "audit"),
        secret_scope=_get_widget_or_env("secret_scope", f"{project}-{env}"),
        bronze_path=_get_widget_or_env("bronze_path", f"s3://{project}-bronze-{env}"),
        silver_path=_get_widget_or_env("silver_path", f"s3://{project}-silver-{env}"),
        gold_path=_get_widget_or_env("gold_path", f"s3://{project}-gold-{env}"),
        checkpoint_path=_get_widget_or_env("checkpoint_path", f"s3://{project}-checkpoints-{env}"),
    )


def get_secret(scope: str, key: str) -> str:
    """Retrieve a secret from Databricks secret scope."""
    spark = SparkSession.getActiveSession()
    from pyspark.dbutils import DBUtils
    dbutils = DBUtils(spark)
    return dbutils.secrets.get(scope=scope, key=key)
