select
    service_type,
    count(*) as trips
from {{ ref('int_trips_unioned') }}
group by service_type;

select
    vendor_id,
    pickup_datetime,
    count(*) as n
from {{ ref('int_trips_unioned') }}
group by vendor_id, pickup_datetime
having count (*) > 1
order by n desc
limit 20;

select 
    count(*) as duplicate_groups,
    sum(n-1) as extra_rows
from (
    select count(*) as n
    from {{ ref("int_trips_unioned") }}
    group by vendor_id, 
             pickup_datetime, 
             pickup_location_id, 
             service_type, 
             dropoff_datetime, 
             dropoff_location_id
    having count(*) > 1
);

with counted as (
    select *,
        count(*) over (
            partition by vendor_id,
                         pickup_datetime,
                         pickup_location_id,
                         dropoff_datetime,
                         dropoff_location_id,
                         service_type
        ) as n
    from {{ ref('int_trips_unioned') }}
)

select
    count(*) as rows_in_duplicate_groups,
    countif(total_amount < 0) as negative_amount_rows
from counted
where n > 1;

select *
from counted
where n > 1
order by vendor_id, pickup_datetime, pickup_location_id
limit 20;

select
    count(*) as total_rows,
    countif(total_amount = 0) as zero_total_trips,
    countif(total_amount < 0) as negative_trips,
    round(sum(total_amount), 2) as total_revenue
from {{ ref('fct_trips') }}