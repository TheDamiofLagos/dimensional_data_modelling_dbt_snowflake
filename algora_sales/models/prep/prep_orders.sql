with orders as (
    select * from {{ ref('base_orders') }}
)

select
    order_id_surrogate,
    order_id,
    customer_id,
    order_date,
    campaign_id,
    campaign_id is not null      as is_campaign_order,
    amount,
    payment_method_id
from orders
