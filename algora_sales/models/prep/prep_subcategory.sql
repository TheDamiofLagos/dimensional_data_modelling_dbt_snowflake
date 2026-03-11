with subcategory as (
    select * from {{ ref('base_subcategory') }}
)

select
    subcategory_id,
    subcategory_name,
    category_id
from subcategory
