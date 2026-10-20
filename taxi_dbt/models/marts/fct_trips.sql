/*
To Do:
- One row per trip (doesn't matter if yellow or green)
- Add a primary key (trip_id). It has to be unique.
- Find all the duplicates, understand why they happen, and fix them,
- Find a way to enrich the column payment_type.
*/

with trips as (
    select * from {{ ref('int_trips_unioned') }}
),

distinct_rows as (
    select distinct *
    from trips
),

combined as (
    select
        --1. the key: these columns define one trip
        vendor_id,
        service_type,
        pickup_datetime,
        dropoff_datetime,
        pickup_location_id,
        dropoff_location_id,
        passenger_count,
        trip_distance,

        --2. descriptive cols: same in all rows of a trip, takes any
        any_value(rate_code_id) as rate_code_id,
        any_value(store_and_fwd_flag) as store_and_fwd_flag,
        any_value(trip_type) as trip_type,

        --3. payment type: from the row with the lowest total (the cancelation if there is one)
        array_agg(payment_type order by total_amount limit 1)[offset(0)] as payment_type,

        --4. money: add up all rows of the trip
        sum(fare_amount) as fare_amount,
        sum(extra) as extra,
        sum(mta_tax) as mta_tax,
        sum(tip_amount) as tip_amount,
        sum(tolls_amount) as tolls_amount,
        sum(ehail_fee) as ehail_fee,
        sum(improvement_surcharge) as improvement_surcharge,
        sum(total_amount) as total_amount

    from distinct_rows
    group by 
        vendor_id,
        service_type,
        pickup_datetime,
        dropoff_datetime,
        pickup_location_id,
        dropoff_location_id,
        passenger_count,
        trip_distance
),

with_trip_id as (
    select
        to_hex(md5(concat(
            coalesce(cast(vendor_id as string), ''), '|',
            coalesce(cast(service_type as string), ''), '|',
            coalesce(cast(pickup_datetime as string), ''), '|',
            coalesce(cast(dropoff_datetime as string), ''), '|',
            coalesce(cast(pickup_location_id as string), ''), '|',
            coalesce(cast(dropoff_location_id as string), ''), '|',
            coalesce(cast(passenger_count as string), ''), '|',
            coalesce(cast(trip_distance as string), '')
        ))) as trip_id,
        *
    from combined
)

select * from with_trip_id