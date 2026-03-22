{{
    config(
        materialized='table'
    )
}}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2016-01-01' as date)",
        end_date="cast('2024-01-01' as date)"
    ) }}
)

select
    date_day,
    dayofweek(date_day)                                 as day_of_week_number,
    dayname(date_day)                                   as day_of_week_name,
    day(date_day)                                       as day_of_month,
    case when dayofweek(date_day) in (0, 6) then true
         else false end                                 as is_weekend,
    date_trunc('week', date_day)                        as week_start_date,
    weekofyear(date_day)                                as week_of_year,
    month(date_day)                                     as month_number,
    monthname(date_day)                                 as month_name,
    quarter(date_day)                                   as quarter_number,
    'Q' || quarter(date_day)::varchar                   as quarter_name,
    year(date_day)                                      as year
from date_spine