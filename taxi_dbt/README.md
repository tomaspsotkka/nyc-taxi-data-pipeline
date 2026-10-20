# taxi_dbt

This dbt project turns raw NYC taxi trip data in BigQuery into clean tables that are easy to analyse.
The raw data (yellow and green taxi trips, and the list of taxi zones) is loaded into BigQuery by Kestra.

## How the data flows

```
Raw tables in BigQuery (loaded by Kestra)
        │
        ▼
staging        One cleaned model per raw table: clear column names, correct data types
        │
        ▼
intermediate   Yellow and green trips combined into one table
        │
        ▼
marts          Final tables for analysis: trips, zones, vendors
```

| Layer | Model | What it does |
|---|---|---|
| staging | `stg_yellow_tripdata` | Cleans yellow taxi trips |
| staging | `stg_green_tripdata` | Cleans green taxi trips, with the same columns as yellow |
| staging | `stg_taxi_zone_lookup` | Cleans the list of taxi zones |
| intermediate | `int_trips_unioned` | Puts yellow and green trips into one table and adds `service_type` (yellow or green) |
| marts | `fct_trips` | One row per trip, with duplicates removed (see below) |
| marts | `dim_zones` | One row per taxi zone, with borough and zone name |
| marts | `dim_vendors` | One row per vendor, with the company name |
| seed | `payment_type_lookup` | Names for the payment type codes (1 = Credit card, 2 = Cash, …), used by `fct_trips` |

## Duplicate trips in `fct_trips`

The raw data has no trip ID, so the same trip can appear more than once.
`fct_trips` makes sure every trip appears only once.

### How we decide that two rows are the same trip

Two rows are treated as the same trip when all of these match:

- `vendor_id` and `service_type` (yellow or green)
- pickup and dropoff time
- pickup and dropoff zone
- `passenger_count` and `trip_distance`

Money columns such as `total_amount` and `payment_type` are **not** part of this check on purpose.
A refund changes the money, but it is still the same trip.

We tested smaller sets of columns first. They were too loose: for example, vendor plus pickup time
alone matched about 8 million groups of rows that were really different trips.

### What kinds of duplicates we found

Before cleaning there were 29,434,964 rows. After cleaning there are 29,388,009 trips (46,955 rows fewer).

| Type | How many | What it is | What we do |
|---|---|---|---|
| Refunds | ~46,800 trips | The trip appears twice: once with the normal price, and once with the same price as a negative number. The negative row cancels the charge, for example because the fare was waived or disputed. | Add both rows together into one trip. The total is usually 0, and the payment type is taken from the cancelling row (for example "No charge" or "Dispute"). |
| Exact copies | 28 trips | The same row was sent twice by the source, identical in every column. | Keep one copy. |
| Yellow and green clashes | a few thousand | A yellow trip and a green trip happened to have the same vendor, time and zone. They looked like one trip only because both tables were combined. | Solved by including `service_type` in the check, so they stay separate trips. |

### Things to know when using `fct_trips`

- Refunded trips have a `total_amount` of 0. The trip still happened, but nobody paid for it in the end.
- About 3,100 trips have a negative `total_amount`. These are refunds whose original trip is in a month
  that is not loaded. They are kept, because they are real refunds.
- Total revenue is the same before and after cleaning, apart from the exact copies, which were counted
  twice before.

## Running the project

You need a dbt profile that connects to BigQuery (`~/.dbt/profiles.yml`). Then:

```bash
dbt build      # build all models and run the tests
dbt docs generate && dbt docs serve --port 8001   # browse the documentation
```
