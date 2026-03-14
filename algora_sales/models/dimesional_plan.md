# Dimensional Layer Build Plan
# algora_sales dbt project

---

## Overview

The dimensional layer is built from prep models following a star schema pattern.
All models are materialized as tables.

Source layer: models/prep/
Target layer: models/dimensional/

---

## Models to Build

### DIMENSIONS (5 models) + 1 BRIDGE

---

#### dim_customer
File: models/dimensional/dim_customer.sql

Source:
  - prep_customer (sole source)

Grain: one row per customer

Columns:
  - customer_id          PK
  - full_name
  - email
  - country

Notes:
  - Straightforward passthrough from prep_customer
  - No joins required

---

#### dim_product
File: models/dimensional/dim_product.sql

Source:
  - prep_product         (driving)
  - prep_subcategory     (LEFT JOIN on subcategory_id)
  - prep_category        (LEFT JOIN on category_id)

Grain: one row per product

Columns:
  - product_id           PK
  - product_name
  - price
  - description
  - subcategory_id
  - subcategory_name
  - category_id
  - category_name

Notes:
  - Denormalises the 3-level product hierarchy (product -> subcategory -> category)
    into a single flat dimension so analysts do not need to join these tables manually
  - Eliminates the need for separate dim_subcategory and dim_category models

---

#### dim_supplier
File: models/dimensional/dim_supplier.sql

Source:
  - prep_supplier (sole source)

Grain: one row per supplier

Columns:
  - supplier_id          PK
  - supplier_name
  - email

Notes:
  - Straightforward passthrough from prep_supplier

---

#### dim_payment_method
File: models/dimensional/dim_payment_method.sql

Source:
  - prep_payment_method (sole source)

Grain: one row per payment method

Columns:
  - payment_method_id    PK
  - payment_method

Notes:
  - Small lookup/reference dimension
  - Straightforward passthrough from prep_payment_method

---

#### dim_marketing_campaign
File: models/dimensional/dim_marketing_campaign.sql

Source:
  - prep_marketing_campaigns (sole source)

Grain: one row per campaign

Columns:
  - campaign_id          PK
  - campaign_name
  - offer_week
  - dbt_run_at           (current_date() — audit column)

Notes:
  - Campaign header only — no join to the bridge table
  - subcategory and discount live in bridge_campaign_subcategory (see below)
  - Cardinality check confirmed 100 rows per campaign_id in prep_campaign_product_subcategory,
    so flattening was not safe. Bridge pattern adopted instead.

---

#### bridge_campaign_subcategory
File: models/dimensional/bridge_campaign_subcategory.sql

Source:
  - prep_campaign_product_subcategory (sole source)

Grain: one row per campaign-subcategory combination

Columns:
  - campaign_product_subcategory_id    PK
  - campaign_id                        FK -> dim_marketing_campaign
  - subcategory_id                     FK -> dim_product (subcategory_id)
  - discount

Notes:
  - Resolves the many-to-many between campaigns and subcategories
  - Join this to dim_marketing_campaign only when subcategory-level campaign
    analysis is needed — do not join it onto fact tables directly

---

### FACTS (3 models)

---

#### fct_order_items
File: models/dimensional/fct_order_items.sql

Source:
  - prep_orderitems      (driving table — sets the grain)
  - prep_orders          (LEFT JOIN on order_id — contributes order-level context)

Grain: one row per order line item

Columns:
  - orderitem_id         PK
  - order_id             degenerate dimension (groups line items back to one order)
  - order_date           FK -> date dimension (if built) / raw date
  - customer_id          FK -> dim_customer
  - product_id           FK -> dim_product
  - supplier_id          FK -> dim_supplier
  - payment_method_id    FK -> dim_payment_method
  - campaign_id          FK -> dim_marketing_campaign (nullable)
  - is_campaign_order    boolean flag (derived: campaign_id is not null)
  - quantity             MEASURE
  - subtotal             MEASURE
  - discount             MEASURE
  - discounted_subtotal  MEASURE

Notes:
  - prep_orderitems drives the join because it owns the grain (line item level)
  - prep_orders contributes customer, date, payment, and campaign context
  - order_id is kept as a degenerate dimension (not a FK to a dim_order)
    so analysts can group all line items belonging to a single order
  - is_campaign_order flag is surfaced here to make campaign filtering trivial
    without needing to join dim_marketing_campaign every time

---

#### fct_returns
File: models/dimensional/fct_returns.sql

Source:
  - prep_returns (sole source)

Grain: one row per return event

Columns:
  - return_id            PK
  - order_id             degenerate dimension / link back to fct_order_items
  - product_id           FK -> dim_product
  - return_date          FK -> date dimension (if built) / raw date
  - reason               degenerate dimension (return reason text)
  - amount_refunded      MEASURE
  - days_to_return       MEASURE

Notes:
  - prep_returns already has days_to_return computed (datediff from order_date)
    so no additional join is needed here
  - order_id is kept as a degenerate dimension — it lets analysts join this fact
    back to fct_order_items at query time to reconcile returns against original sales
  - No dim_order exists, so order_id has no FK enforcement target

---

#### fct_ratings
File: models/dimensional/fct_ratings.sql

Source:
  - prep_customer_product_ratings (sole source)

Grain: one row per customer-product rating event

Columns:
  - customerproductrating_id    PK
  - customer_id                 FK -> dim_customer
  - product_id                  FK -> dim_product
  - ratings                     MEASURE (numeric 1-5)
  - rating_tier                 degenerate dimension (high / medium / low)
  - review                      degenerate dimension (free text)
  - sentiment                   degenerate dimension (good / bad)

Notes:
  - rating_tier, review, and sentiment are kept on the fact row — they describe
    the rating event itself, not a reusable entity, so no separate dim is needed
  - ratings (numeric) is the only true additive measure; rating_tier/sentiment
    are descriptive attributes that support filtering and grouping

---

## Build Order

Step 1 — Build independent dimensions (no cross-dim dependencies):
  1. dim_customer
  2. dim_supplier
  3. dim_payment_method

Step 2 — Build dimensions with internal joins:
  4. dim_product                 (joins prep_subcategory + prep_category)
  5. dim_marketing_campaign      (passthrough from prep_marketing_campaigns)
  6. bridge_campaign_subcategory (passthrough from prep_campaign_product_subcategory)

Step 3 — Build fact tables (all dims must exist first):
  7. fct_order_items
  8. fct_returns
  9. fct_ratings

dbt command to run the full dimensional layer in one go:
  dbt run --select dimensional.*

---

## Open Decisions

1. DATE DIMENSION
   A dim_date (date spine with day_of_week, month, quarter, is_weekend etc.)
   can be generated using dbt_utils.date_spine seeded from the min/max order_date.
   Currently not included in this plan. Add if BI tool requires a proper date dim.

2. CAMPAIGN BRIDGE TABLE [RESOLVED]
   Cardinality check showed 100 rows per campaign_id in prep_campaign_product_subcategory.
   Flattening was not safe. Implemented as:
     - dim_marketing_campaign       (campaign header only: campaign_id, campaign_name, offer_week)
     - bridge_campaign_subcategory  (campaign_id, subcategory_id, discount)

3. SURROGATE KEYS
   prep_orders already has order_id_surrogate. Surrogate keys have not been added
   to other dimensions in this plan. Add if source natural keys are not stable
   or if SCD (slowly changing dimension) tracking is required in future.

---

## File Checklist

models/dimensional/
  DIMENSIONAL_PLAN.md                    <- this file
  dim_customer.sql
  dim_product.sql
  dim_supplier.sql
  dim_payment_method.sql
  dim_marketing_campaign.sql
  bridge_campaign_subcategory.sql
  fct_order_items.sql
  fct_returns.sql
  fct_ratings.sql
  _dimensional.yml                       <- tests and documentation for all models