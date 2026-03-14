{{ 
    config(
        materialized='table'
        )
}}

select 
    payment_method_id,
    payment_method,
    current_date() as dbt_run_at
from {{ ref('prep_payment_method' )}}