with returns as (
    select * from {{ ref('base_returns') }}
),

orders as (
    select
        order_id,
        order_date
    from {{ ref('base_orders') }}
)

select
    returns.return_id,
    returns.order_id,
    returns.product_id,
    returns.return_date,
    returns.reason,
    returns.amount_refunded,
    datediff('day', orders.order_date, returns.return_date)  as days_to_return
from returns
left join orders on returns.order_id = orders.order_id
