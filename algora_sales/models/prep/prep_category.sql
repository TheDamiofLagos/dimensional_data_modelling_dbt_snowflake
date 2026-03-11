with category as (
    select * from {{ ref('base_category') }}
)

select
    category_id,
    category_name
from category
