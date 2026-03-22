{{
    config(
        materialized='table'
    )
}}

select
    oi.order_date,
    d.day_of_week_name,
    d.is_weekend,
    d.week_start_date,
    d.month_name,
    d.quarter_name,
    d.year,
    oi.orderitem_id,
    oi.order_id,
    oi.quantity,
    oi.subtotal,
    oi.discount,
    oi.discounted_subtotal,
    oi.is_campaign_order,
    c.customer_id,
    c.full_name as customer_name,
    c.country as customer_country,
    c.sub_region,
    c.region,
    p.product_name,
    p.category,
    p.subcategory,
    p.product_price,
    s.supplier_name,
    pm.payment_method,
    mc.campaign_name,
    mc.offer_week
from {{ ref('fct_order_items') }} oi
left join {{ ref('dim_date') }} d on oi.order_date = d.date_day
left join {{ ref('dim_customer') }} c on oi.customer_id = c.customer_id
left join {{ ref('dim_product') }} p on oi.product_id = p.product_id
left join {{ ref('dim_supplier') }} s on oi.supplier_id = s.supplier_id
left join {{ ref('dim_payment_method') }} pm on oi.payment_method_id = pm.payment_method_id
left join {{ ref('dim_marketing_campaign') }} mc on oi.campaign_id = mc.campaign_id
