{{ 
    config(
        materialized='table'
        ) 
}}

select 
    pc.customer_id,
    pc.first_name,
    pc.last_name,
    pc.full_name,
    pc.email,
    pc.country,
    crm.sub_region,
    crm.region,
    current_date() as dbt_run_at
from {{ ref('prep_customer')}} pc
left join {{ ref('country_region_mapping')}} crm on pc.country = crm.country