with
    base as (
        select
            *
        from {{ source('transactional_data_output', 'orderitems') }}
    )

select * from base
