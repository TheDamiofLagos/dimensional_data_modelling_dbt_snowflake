{{ 
    config(
        materialized='table'
        )
}}

select 
    supplier_id,
    supplier_name,
    email as supplier_email,
    current_date() as dbt_run_at
from {{ ref('prep_supplier')}}