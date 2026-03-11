{{ 
    config(
        materialized='table'
    ) 
}}

with orderitems as (
    select * from {{ ref('base_orderitems') }}
)

select
    orderitem_id,
    order_id,
    product_id,
    quantity,
    supplier_id,
    subtotal,
    discount,
    {{ apply_discount('subtotal', 'discount') }}  as discounted_subtotal
from orderitems
