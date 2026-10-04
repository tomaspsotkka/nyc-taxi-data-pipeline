select 
    cast(locationid as int) as location_id,
    cast(borough as string) as borough,
    cast(zone as string) as zone,
    cast(service_zone as string) as service_zone

from {{ source('raw_data', 'taxi_zone_lookup')}}