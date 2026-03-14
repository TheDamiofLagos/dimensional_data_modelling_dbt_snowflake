{{
    config(
        materialized='incremental',
        unique_key='return_id',
        incremental_strategy='merge'
    )
}}

select
    return_id,
    order_id,
    product_id,
    return_date,
    reason,
    amount_refunded,
    days_to_return
from {{ ref('prep_returns') }}

{% if is_incremental() %}
  where return_date > (select max(return_date) from {{ this }})
{% endif %}
