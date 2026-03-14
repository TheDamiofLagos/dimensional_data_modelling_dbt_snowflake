{{
    config(
        materialized='table'
    )
}}

select
    campaign_product_subcategory_id,
    campaign_id,
    subcategory_id,
    discount
from {{ ref('prep_campaign_product_subcategory') }}
