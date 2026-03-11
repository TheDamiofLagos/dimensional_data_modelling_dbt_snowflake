with marketing_campaigns as (
    select * from {{ ref('base_marketing_campaigns') }}
)

select
    campaign_id,
    campaign_name,
    offer_week
from marketing_campaigns
