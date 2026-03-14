{{
    config(
        materialized='table'
    )
}}

select
    customerproductrating_id,
    customer_id,
    product_id,
    ratings,
    rating_tier,
    review,
    sentiment
from {{ ref('prep_customer_product_ratings') }}
