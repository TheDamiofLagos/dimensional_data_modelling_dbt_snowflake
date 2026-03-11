# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `algora_sales`, a dbt (data build tool) analytics engineering project that transforms raw Snowflake data into analytics-ready models. The source data lives in Snowflake database `RAW_BUSINESS_DATA`, schema `transactional_data_output`.

## Common Commands

All dbt commands should be run from the `algora_sales/` directory with the Python virtual environment activated:

```bash
# Activate virtual environment (from project root)
source algora_env/Scripts/activate   # bash on Windows

cd algora_sales

# Install dbt packages
dbt deps

# Build all models
dbt build

# Run all models (no tests)
dbt run

# Run tests only
dbt test

# Run a single model
dbt run --select base_product

# Run a single model and its tests
dbt build --select base_product

# Run all models in a layer
dbt run --select base.*
dbt run --select prep.*
dbt run --select dimensional.*
dbt run --select present.*

# Preview model output (shows column names and sample rows)
dbt show --select base_orders --limit 5

# Run an ad-hoc query against a materialized model (useful for data validation)
dbt show --inline "select count(*) from {{ ref('base_orders') }}"

# Compile SQL without running
dbt compile

# Clean build artifacts
dbt clean
```

## Architecture

The project follows a four-layer transformation pattern:

```
Snowflake (RAW_BUSINESS_DATA.transactional_data_output)
    ↓
models/base/        → materialized as views   (1:1 with source tables, no business logic)
    ↓
models/prep/        → materialized as tables  (cleaning, type casting, derived columns)
    ↓
models/dimensional/ → materialized as tables  (dimension and fact tables)
    ↓
models/present/     → materialized as tables  (reporting/BI-facing models)
```

### Layer Descriptions

* **Base:** The area for rename, recast, categorising. Very close to [dbt's staging layer.](https://docs.getdbt.com/guides/best-practices/how-we-structure/2-staging)
* **Prep:** An area for **doing things** to get to models. Very close to [dbt's intermediate layer](https://docs.getdbt.com/guides/best-practices/how-we-structure/3-intermediate).
* **Dimensional:** An area where every entity is either a dim or a fact.
* **Presentation:** Wide, denormalised tables for users to query.

**Source tables** (defined in `models/base/_src_transactional_data_output.yml`):
`orders`, `orderitems`, `product`, `category`, `subcategory`, `customer`, `returns`, `supplier`, `payment_method`, `customer_product_ratings`, `marketing_campaigns`, `campaign_product_subcategory`

**Base models** are thin wrappers that reference sources via `{{ source('transactional_data_output', '<table>') }}`. They do not contain business logic.

**Prep models** (`models/prep/`) are where transformations, joins, and derived columns should be built, referencing base models via `ref()`.

**Dimensional models** (`models/dimensional/`) contain dimension and fact tables built from prep models.

**Present models** (`models/present/`) are BI/reporting-facing models built from dimensional models.

## Macros

All macros are Snowflake-only — no `adapter.dispatch`. Each is a simple Jinja wrapper around Snowflake SQL.

| Macro | Usage |
|---|---|
| `cents_to_dollars(column_name)` | Converts integer cents to decimal dollars. `{{ cents_to_dollars('amount') }}` |
| `full_name(first_name, last_name)` | Concatenates first and last name via `CONCAT_WS`. `{{ full_name('first_name', 'last_name') }}` |
| `apply_discount(price, discount_rate)` | Returns `price * (1 - discount_rate)` cast to `numeric(16,2)`. `{{ apply_discount('price', 'discount') }}` |
| `classify_rating(rating_col)` | Buckets a 1–5 numeric rating into `'high'` (≥4) / `'medium'` (≥3) / `'low'`. `{{ classify_rating('ratings') }}` |
| `safe_divide(numerator, denominator)` | Divides two values, returning `NULL` instead of erroring on divide-by-zero. `{{ safe_divide('returns', 'orders') }}` |

## Testing Pattern

Column-level tests are defined in `.yml` files alongside the model SQL. Every base model has a corresponding `.yml` file with full column coverage. Current test types in use:
- `not_null`, `unique` on primary keys and unique natural keys (e.g. customer email)
- `relationships` (FK validation) using `ref()` to reference other models
- `accepted_values` on categorical columns (e.g. `sentiment`, `payment_method`)

The `relationships` and `accepted_values` tests use an `arguments` wrapper:
```yaml
data_tests:
  - not_null
  - unique
  - relationships:
      arguments:
        to: ref('base_subcategory')
        field: subcategory_id
  - accepted_values:
      arguments:
        values: ['good', 'bad']
```

Before adding a `unique` test to a non-PK column, verify with:
```bash
dbt show --inline "select count(*) as total, count(distinct <col>) as distinct_vals from {{ ref('<model>') }}"
```

## Snowflake Connection

The profile `algora_sales` must be configured in `~/.dbt/profiles.yml`. Authentication uses a private key file (`snowflake_key.p8` at the project root — never commit this file).

## Dependencies

- `dbt-labs/dbt_utils >= 1.3.0` (install with `dbt deps`)
- Python 3.14.3 (via `algora_env/`)
