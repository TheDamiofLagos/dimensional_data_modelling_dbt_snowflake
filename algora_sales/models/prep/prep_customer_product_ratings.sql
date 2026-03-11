with customer_product_ratings as (
    select * from {{ ref('base_customer_product_ratings') }}
)

select
    customerproductrating_id,
    customer_id,
    product_id,
    ratings,
    {{ classify_rating('ratings') }}  as rating_tier,
    review,
    sentiment
from customer_product_ratings
