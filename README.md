# Algora Sales — dbt Analytics Engineering Project

A dbt project that transforms raw transactional data in Snowflake into clean,
analytics-ready models used by business stakeholders and connected to Looker
Studio dashboards.

---

## Table of Contents

1. [What this project does](#what-this-project-does)
2. [How data flows through the project](#how-data-flows-through-the-project)
3. [Project structure](#project-structure)
4. [Models](#models)
   - [Base layer](#base-layer)
   - [Prep layer](#prep-layer)
   - [Dimensional layer](#dimensional-layer)
   - [Present layer](#present-layer)
5. [Snapshots](#snapshots)
6. [Macros](#macros)
7. [Testing](#testing)
8. [Local setup](#local-setup)
9. [Running the project](#running-the-project)
10. [CI/CD pipeline](#cicd-pipeline)

---

## What this project does

Raw business data arrives in Snowflake every day — orders, customers, products,
campaigns, returns, and ratings. That raw data is messy: column names are
inconsistent, data types need casting, and business logic is buried.

This project uses **dbt (data build tool)** to transform that raw data step by
step into clean, reliable tables that business users and dashboards can query
directly. No SQL knowledge is required to use the final output — just connect
your BI tool and go.

---

## How data flows through the project

Data moves through four layers, each building on the previous:

```
Snowflake — RAW_BUSINESS_DATA.transactional_data_output
        │
        │  (raw source tables: orders, customers, products, etc.)
        │
        ▼
    BASE layer  →  Views — rename columns, cast types, no logic
        │
        ▼
    PREP layer  →  Tables — clean, join, derive new columns
        │
        ▼
DIMENSIONAL layer  →  Tables — dimension and fact tables
        │
        ▼
   PRESENT layer  →  Tables — wide, flat tables for dashboards
        │
        ▼
  Looker Studio — connected directly to the present layer
```

Think of it like a factory assembly line. Each station (layer) does one job and
hands a cleaner product to the next station.

---

## Project structure

```
algora_sales/
├── models/
│   ├── base/           → one model per source table
│   ├── prep/           → transformations and joins
│   ├── dimensional/    → dimension and fact tables
│   └── present/        → stakeholder-facing reporting tables
├── snapshots/          → tracks slowly changing dimension history
├── macros/             → reusable SQL functions
├── packages.yml        → third-party dbt packages
└── dbt_project.yml     → project configuration

.github/
└── workflows/
    ├── ci.yml          → runs on every pull request
    └── deploy.yml      → runs on merge to main and on a daily schedule
```

---

## Models

### Base layer

**Location:** `models/base/`
**Materialized as:** Views

The base layer is the entry point. Each model maps 1:1 to a raw source table in
Snowflake. No business logic lives here — only renaming, recasting, and light
categorisation. The goal is to give every downstream model a consistent,
well-named starting point.

| Model | Source table | What it does |
|---|---|---|
| `base_orders` | `orders` | Renames and casts order header fields |
| `base_orderitems` | `orderitems` | Renames and casts line-item fields |
| `base_customer` | `customer` | Renames customer fields, standardises casing |
| `base_product` | `product` | Renames product fields |
| `base_category` | `category` | Renames category fields |
| `base_subcategory` | `subcategory` | Renames subcategory fields |
| `base_supplier` | `supplier` | Renames supplier fields |
| `base_returns` | `returns` | Renames returns and refund fields |
| `base_payment_method` | `payment_method` | Renames payment method fields |
| `base_customer_product_ratings` | `customer_product_ratings` | Renames rating and sentiment fields |
| `base_marketing_campaigns` | `marketing_campaigns` | Renames campaign fields |
| `base_campaign_product_subcategory` | `campaign_product_subcategory` | Renames campaign-product bridge fields |

---

### Prep layer

**Location:** `models/prep/`
**Materialized as:** Tables

The prep layer is where the real transformation work happens. Models here join
base models together, apply business logic, derive calculated columns, and
produce clean, enriched records ready to feed into dimensional models.

Examples of what happens here:
- Concatenating first and last name into a full name
- Converting amounts from cents to dollars
- Applying discount rates to get discounted prices
- Classifying ratings as high / medium / low
- Joining products to their categories and subcategories

---

### Dimensional layer

**Location:** `models/dimensional/`
**Materialized as:** Tables

The dimensional layer organises data into the classic **star schema** pattern —
dimensions and facts.

**What is a dimension?** A dimension describes a *thing* — a customer, a
product, a campaign. It answers the question "who?" or "what?".

**What is a fact?** A fact records an *event* — an order line item, a return,
a rating. It answers the question "what happened?". Facts contain numbers you
can aggregate (totals, counts, averages) and foreign keys pointing to dimensions.

| Model | Type | Description |
|---|---|---|
| `dim_customer` | Dimension | One row per customer, built from the customer snapshot (tracks history) |
| `dim_product` | Dimension | One row per product with category and subcategory |
| `dim_supplier` | Dimension | One row per supplier |
| `dim_payment_method` | Dimension | One row per payment method |
| `dim_marketing_campaign` | Dimension | One row per marketing campaign |
| `bridge_campaign_subcategory` | Bridge | Links campaigns to the subcategories they target (many-to-many) |
| `fct_order_items` | Fact | One row per order line item — the core transactional fact table |
| `fct_returns` | Fact | One row per return, with refund amount |
| `fct_ratings` | Fact | One row per product rating given by a customer |

---

### Present layer

**Location:** `models/present/`
**Materialized as:** Tables

The present layer is what business stakeholders and Looker Studio dashboards
connect to. These are wide, denormalised tables — everything a stakeholder needs
for a given subject area is in one place. No joins required.

| Model | Description | Key metrics |
|---|---|---|
| `present_sales_overview` | One row per order line item, enriched with customer, product, supplier, payment, and campaign details | Revenue, discounts, quantities by any dimension |
| `present_customer_360` | One row per customer with their full lifetime activity | Total orders, revenue, returns, return rate, average rating given |
| `present_product_performance` | One row per product with aggregated sales, returns, and ratings | Units sold, revenue, return rate, average rating |
| `present_campaign_effectiveness` | One row per campaign with order and revenue attribution | Campaign-driven revenue, total discounts given, campaign revenue rate |

---

## Snapshots

**Location:** `snapshots/`

Snapshots solve the **slowly changing dimension** problem. Customer data changes
over time — someone might move country or change their email. Without a snapshot,
you'd lose that history when the record is updated.

The `snapshot_customer` snapshot tracks changes to the `customer` table using a
**check strategy** — whenever `email` or `country` changes on a customer record,
dbt inserts a new row and closes off the old one with a `dbt_valid_to` date.
This means you can always ask "what country was this customer in when they placed
this order?" — even years later.

```
customer_id  country   dbt_valid_from  dbt_valid_to
1            France    2023-01-01      2025-06-01      ← old record, now closed
1            UK        2025-06-01      9999-12-31      ← current record
```

`dim_customer` is built from this snapshot, so it always reflects the most
current customer state while preserving history.

---

## Macros

Macros are reusable SQL functions written in Jinja. Instead of writing the same
logic repeatedly across models, you call the macro once and it generates the SQL
for you.

| Macro | What it does | Example usage |
|---|---|---|
| `cents_to_dollars(column)` | Converts integer cents to decimal dollars | `{{ cents_to_dollars('amount') }}` |
| `full_name(first, last)` | Concatenates first and last name | `{{ full_name('first_name', 'last_name') }}` |
| `apply_discount(price, rate)` | Returns `price * (1 - rate)` | `{{ apply_discount('price', 'discount') }}` |
| `classify_rating(rating)` | Buckets 1–5 ratings into high / medium / low | `{{ classify_rating('rating') }}` |
| `safe_divide(numerator, denominator)` | Divides two values, returns NULL instead of erroring on zero | `{{ safe_divide('returns', 'orders') }}` |

---

## Testing

Every model has a companion `.yml` file that defines column-level data tests.
Tests run automatically as part of `dbt build` and will fail the build if data
quality issues are found.

Tests in use:

- `not_null` — ensures a column has no missing values
- `unique` — ensures a column has no duplicate values (used on primary keys)
- `relationships` — validates that a foreign key exists in the referenced table
- `accepted_values` — validates that a column only contains expected values
  (e.g. sentiment is only ever `'good'` or `'bad'`)

Tests run in CI on every pull request, so broken data can never reach production.

---

## Local setup

### Prerequisites

- [dbt Fusion](https://docs.getdbt.com/docs/core/installation-overview) installed via VS Code
- Access to the Snowflake account with `RAW_BUSINESS_DATA` database
- A Snowflake private key file (`snowflake_key.p8`)

### Configure your Snowflake connection

Create or edit `~/.dbt/profiles.yml` with the following content. This file
lives outside the repo — never commit it, as it contains credentials.

```yaml
algora_sales:
  target: dev
  outputs:

    dev:
      type: snowflake
      account: <your_snowflake_account>
      user: <your_username>
      private_key_path: /path/to/snowflake_key.p8
      database: RAW_BUSINESS_DATA
      schema: <your_dev_schema>
      warehouse: <your_warehouse>
      role: <your_role>
      threads: 4

    prod:
      type: snowflake
      account: <your_snowflake_account>
      user: <your_username>
      private_key_path: /path/to/snowflake_key.p8
      database: RAW_BUSINESS_DATA
      schema: business_analytics_prod
      warehouse: <your_warehouse>
      role: <your_role>
      threads: 4
```

---

## Running the project

All commands are run from the `algora_sales/` directory.

```bash
cd algora_sales

# Install dbt packages (run once, or after updating packages.yml)
dbt deps

# Build everything — runs all models and all tests
dbt build

# Run models only (skips tests)
dbt run

# Run tests only
dbt test

# Run a single model and its tests
dbt build --select present_sales_overview

# Run an entire layer
dbt run --select base.*
dbt run --select prep.*
dbt run --select dimensional.*
dbt run --select present.*

# Preview the first 5 rows of a model
dbt show --select present_customer_360 --limit 5

# Run a quick ad-hoc query against any model
dbt show --inline "select count(*) from {{ ref('fct_order_items') }}"

# Build against production (writes to business_analytics_prod)
dbt build --target prod
```

---

## CI/CD pipeline

This project uses **GitHub Actions** to automate testing and deployment. No
manual steps are needed beyond opening a pull request.

### How it works

```
You open a Pull Request → main
        ↓
GitHub spins up a Linux machine
        ↓
Installs dbt Fusion, connects to Snowflake using encrypted secrets
        ↓
Runs dbt build against the business_analytics_ci schema
        ↓
PASS → green check, PR can be merged
FAIL → red cross, PR is blocked until fixed
        ↓
You merge the PR
        ↓
GitHub automatically deploys to business_analytics_prod
        ↓
Every day at 6am UTC, production refreshes automatically
```

### Workflow files

| File | Trigger | Target schema |
|---|---|---|
| `.github/workflows/ci.yml` | Every pull request to `main` | `business_analytics_ci` |
| `.github/workflows/deploy.yml` | Merge to `main` + daily 6am UTC | `business_analytics_prod` |

### Required GitHub Secrets

The following secrets must be configured in **GitHub → Settings → Secrets and
variables → Actions** before the workflows will run successfully.

| Secret name | What it contains |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Your Snowflake account identifier |
| `SNOWFLAKE_USER` | Your Snowflake username |
| `SNOWFLAKE_PRIVATE_KEY` | Full contents of your `snowflake_key.p8` file |
| `SNOWFLAKE_WAREHOUSE` | Your Snowflake warehouse name |
| `SNOWFLAKE_DATABASE` | `RAW_BUSINESS_DATA` |
| `SNOWFLAKE_ROLE` | Your Snowflake role |

Secrets are encrypted and injected at runtime. They never appear in logs or in
any committed file.
