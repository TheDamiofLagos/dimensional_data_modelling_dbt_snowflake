{{
    config(
        materialized='table'
    )
}}

with orders as (
    select
        customer_id,
        count(distinct order_id)          as total_orders,
        count(orderitem_id)               as total_items,
        sum(discounted_subtotal)          as total_revenue,
        sum(subtotal - discounted_subtotal) as total_discount_given,
        {{ safe_divide('sum(discounted_subtotal)', 'count(distinct order_id)') }} as avg_order_value
    from {{ ref('fct_order_items') }}
    group by customer_id
),

returns as (
    select
        oi.customer_id,
        count(r.return_id)      as total_returns,
        sum(r.amount_refunded)  as total_refunded
    from {{ ref('fct_returns') }} r
    join (
        select distinct order_id, customer_id from {{ ref('fct_order_items') }}
    ) oi on r.order_id = oi.order_id
    group by oi.customer_id
),

ratings as (
    select
        customer_id,
        round(avg(ratings), 2)              as avg_rating_given,
        count(customerproductrating_id)     as total_reviews
    from {{ ref('fct_ratings') }}
    group by customer_id
)

select
    c.customer_id,
    c.full_name,
    c.email,
    c.country,
    c.sub_region,
    c.region,
    coalesce(o.total_orders, 0)        as total_orders,
    coalesce(o.total_items, 0)         as total_items,
    coalesce(o.total_revenue, 0)       as total_revenue,
    coalesce(o.total_discount_given, 0) as total_discount_given,
    o.avg_order_value,
    coalesce(r.total_returns, 0)       as total_returns,
    coalesce(r.total_refunded, 0)      as total_refunded,
    {{ safe_divide('r.total_returns', 'o.total_items') }} as return_rate,
    rt.avg_rating_given,
    coalesce(rt.total_reviews, 0)      as total_reviews
from {{ ref('dim_customer') }} c
left join orders o  on c.customer_id = o.customer_id
left join returns r on c.customer_id = r.customer_id
left join ratings rt on c.customer_id = rt.customer_id
