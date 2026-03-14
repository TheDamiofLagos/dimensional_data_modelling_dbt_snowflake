{{ 
    config(
        materialized='table'
        ) 
}}

select 
    customer_id,
    first_name,
    last_name,
    full_name,
    email,
    country,
    current_date() as dbt_run_at
from {{ ref('prep_customer')}}