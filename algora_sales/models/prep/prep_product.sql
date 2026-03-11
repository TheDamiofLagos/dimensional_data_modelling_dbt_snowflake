with product as (
    select * from {{ ref('base_product') }}
)

select
    product_id,
    name,
    price,
    description,
    subcategory_id
from product
