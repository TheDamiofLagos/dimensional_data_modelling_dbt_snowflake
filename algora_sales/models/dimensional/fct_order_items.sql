{{
    config(
        materialized='incremental',
        unique_key='orderitem_id',
        incremental_strategy='merge'
    )
}}

with orderitems as (
    select * from {{ ref('prep_orderitems') }}
),

orders as (
    select * from {{ ref('prep_orders') }}
)

select
    o.order_date,
    oi.orderitem_id,
    oi.order_id,
    o.customer_id,
    oi.product_id,
    oi.supplier_id,
    o.payment_method_id,
    o.campaign_id,
    o.is_campaign_order,
    oi.quantity,
    oi.subtotal,
    oi.discount,
    oi.discounted_subtotal
from orderitems as oi
left join orders as o on oi.order_id = o.order_id

{% if is_incremental() %}
  -- Filter only new or updated rows
  where o.order_date > (select max(order_date) from {{ this }})
{% endif %}
