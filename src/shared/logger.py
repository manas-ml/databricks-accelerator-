"""
Structured pipeline logger. Writes JSON log records to console and optionally
to an audit Delta table at {catalog}.audit.pipeline_logs.
"""
import json
import logging
import time
from datetime import datetime, timezone
from typing import Any, Dict, Optional


class PipelineLogger:
    def __init__(
        self,
        pipeline_name: str,
        layer: str,
        catalog: str,
        audit_schema: str = "audit",
        audit_table: str = "pipeline_logs",
        spark=None,
    ):
        self.pipeline_name = pipeline_name
        self.layer = layer
        self.catalog = catalog
        self.audit_table = f"{catalog}.{audit_schema}.{audit_table}"
        self.spark = spark
        self._records: list[Dict[str, Any]] = []

        self._console = logging.getLogger(pipeline_name)
        if not self._console.handlers:
            handler = logging.StreamHandler()
            handler.setFormatter(logging.Formatter("%(message)s"))
            self._console.addHandler(handler)
            self._console.setLevel(logging.INFO)

    def _record(self, level: str, message: str, **kwargs) -> Dict[str, Any]:
        record = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "pipeline": self.pipeline_name,
            "layer": self.layer,
            "level": level,
            "message": message,
            **kwargs,
        }
        self._console.info(json.dumps(record))
        self._records.append(record)
        return record

    def info(self, message: str, **kwargs):
        self._record("INFO", message, **kwargs)

    def warn(self, message: str, **kwargs):
        self._record("WARN", message, **kwargs)

    def error(self, message: str, **kwargs):
        self._record("ERROR", message, **kwargs)

    def log_metrics(self, rows_read: int, rows_written: int, duration_seconds: float, **kwargs):
        self._record(
            "METRICS",
            "Pipeline metrics",
            rows_read=rows_read,
            rows_written=rows_written,
            duration_seconds=round(duration_seconds, 2),
            **kwargs,
        )

    def flush_to_delta(self):
        """Write accumulated log records to the audit Delta table."""
        if not self._records or self.spark is None:
            return
        try:
            from pyspark.sql import Row
            df = self.spark.createDataFrame([Row(**r) for r in self._records])
            df.write.format("delta").mode("append").saveAsTable(self.audit_table)
            self._records.clear()
        except Exception as e:
            self._console.warning(f"Failed to flush logs to Delta: {e}")


def timer(func):
    """Decorator that logs execution time of a function."""
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        print(json.dumps({"function": func.__name__, "duration_seconds": round(elapsed, 2)}))
        return result
    return wrapper
