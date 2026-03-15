{{
    config(
        materialized='table'
    )
}}

with sales as (
    select
        product_id,
        count(orderitem_id)       as total_orders,
        sum(quantity)             as total_units_sold,
        sum(discounted_subtotal)  as total_revenue
    from {{ ref('fct_order_items') }}
    group by product_id
),

returns as (
    select
        product_id,
        count(return_id)       as total_returns,
        sum(amount_refunded)   as total_refunded
    from {{ ref('fct_returns') }}
    group by product_id
),

ratings as (
    select
        product_id,
        round(avg(ratings), 2)          as avg_rating,
        count(customerproductrating_id) as total_reviews
    from {{ ref('fct_ratings') }}
    group by product_id
)

select
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.product_price,
    coalesce(s.total_orders, 0)      as total_orders,
    coalesce(s.total_units_sold, 0)  as total_units_sold,
    coalesce(s.total_revenue, 0)     as total_revenue,
    coalesce(r.total_returns, 0)     as total_returns,
    coalesce(r.total_refunded, 0)    as total_refunded,
    {{ safe_divide('r.total_returns', 's.total_units_sold') }} as return_rate,
    rt.avg_rating,
    coalesce(rt.total_reviews, 0)    as total_reviews
from {{ ref('dim_product') }} p
left join sales s   on p.product_id = s.product_id
left join returns r on p.product_id = r.product_id
left join ratings rt on p.product_id = rt.product_id
