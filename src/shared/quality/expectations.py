"""
Reusable data quality expectation library.
Works with both plain PySpark DataFrames and Delta Live Tables expectations.
"""
from dataclasses import dataclass
from typing import List, Optional
from pyspark.sql import DataFrame
from pyspark.sql import functions as F


@dataclass
class DQResult:
    table: str
    expectation: str
    passed: bool
    failing_rows: int
    total_rows: int
    pass_rate: float


def not_null(df: DataFrame, column: str) -> DQResult:
    total = df.count()
    failing = df.filter(F.col(column).isNull()).count()
    return DQResult(
        table="",
        expectation=f"not_null({column})",
        passed=failing == 0,
        failing_rows=failing,
        total_rows=total,
        pass_rate=round((total - failing) / total, 4) if total else 0.0,
    )


def unique(df: DataFrame, columns: List[str]) -> DQResult:
    total = df.count()
    dedup = df.select(*columns).distinct().count()
    failing = total - dedup
    return DQResult(
        table="",
        expectation=f"unique({','.join(columns)})",
        passed=failing == 0,
        failing_rows=failing,
        total_rows=total,
        pass_rate=round(dedup / total, 4) if total else 0.0,
    )


def in_range(df: DataFrame, column: str, min_val, max_val) -> DQResult:
    total = df.count()
    failing = df.filter(
        (F.col(column) < min_val) | (F.col(column) > max_val)
    ).count()
    return DQResult(
        table="",
        expectation=f"in_range({column}, {min_val}, {max_val})",
        passed=failing == 0,
        failing_rows=failing,
        total_rows=total,
        pass_rate=round((total - failing) / total, 4) if total else 0.0,
    )


def regex_match(df: DataFrame, column: str, pattern: str) -> DQResult:
    total = df.count()
    failing = df.filter(~F.col(column).rlike(pattern)).count()
    return DQResult(
        table="",
        expectation=f"regex_match({column}, {pattern!r})",
        passed=failing == 0,
        failing_rows=failing,
        total_rows=total,
        pass_rate=round((total - failing) / total, 4) if total else 0.0,
    )


def accepted_values(df: DataFrame, column: str, values: List) -> DQResult:
    total = df.count()
    failing = df.filter(~F.col(column).isin(values)).count()
    return DQResult(
        table="",
        expectation=f"accepted_values({column}, {values})",
        passed=failing == 0,
        failing_rows=failing,
        total_rows=total,
        pass_rate=round((total - failing) / total, 4) if total else 0.0,
    )


def run_suite(df: DataFrame, checks: list, table_name: str = "") -> List[DQResult]:
    """Run a list of DQ check functions and return results."""
    results = []
    for check_fn in checks:
        result = check_fn(df)
        result.table = table_name
        results.append(result)
    return results


def assert_suite(results: List[DQResult], raise_on_failure: bool = True) -> bool:
    """Assert all DQ results passed. Raises ValueError if raise_on_failure=True."""
    failed = [r for r in results if not r.passed]
    if failed and raise_on_failure:
        summary = "; ".join(
            f"{r.expectation} ({r.failing_rows}/{r.total_rows} rows failed)"
            for r in failed
        )
        raise ValueError(f"Data quality checks failed: {summary}")
    return len(failed) == 0


# ---------------------------------------------------------------------------
# DLT expectation strings (for use in @dlt.expect decorators)
# ---------------------------------------------------------------------------
DLT_EXPECTATIONS = {
    "valid_id": "id IS NOT NULL",
    "valid_event_ts": "event_ts IS NOT NULL",
    "valid_amount": "amount >= 0",
    "valid_status": "status IN ('active', 'inactive', 'pending')",
}
