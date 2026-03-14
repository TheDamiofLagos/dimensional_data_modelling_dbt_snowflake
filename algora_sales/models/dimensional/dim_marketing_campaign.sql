{{
    config(
        materialized='table'
    )
}}

select
    campaign_id,
    campaign_name,
    offer_week,
    current_date() as dbt_run_at
from {{ ref('prep_marketing_campaigns') }}