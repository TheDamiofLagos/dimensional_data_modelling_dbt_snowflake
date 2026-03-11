with campaign_product_subcategory as (
    select * from {{ ref('base_campaign_product_subcategory') }}
)

select
    campaign_product_subcategory_id,
    campaign_id,
    subcategory_id,
    discount
from campaign_product_subcategory
