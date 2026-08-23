#!/usr/bin/env python
# coding: utf-8

import click
import pandas as pd
from sqlalchemy import create_engine
from tqdm.auto import tqdm


DATASETS = {
    'yellow': {
        'url_template': 'https://github.com/DataTalksClub/nyc-tlc-data/releases/download/yellow/yellow_tripdata_{year}-{month:02d}.csv.gz',
        'dtype': {
            "VendorID": "Int64",
            "passenger_count": "Int64",
            "trip_distance": "float64",
            "RatecodeID": "Int64",
            "store_and_fwd_flag": "string",
            "PULocationID": "Int64",
            "DOLocationID": "Int64",
            "payment_type": "Int64",
            "fare_amount": "float64",
            "extra": "float64",
            "mta_tax": "float64",
            "tip_amount": "float64",
            "tolls_amount": "float64",
            "improvement_surcharge": "float64",
            "total_amount": "float64",
            "congestion_surcharge": "float64"
        },
        'parse_dates': ["tpep_pickup_datetime", "tpep_dropoff_datetime"],
        'default_table': 'yellow_taxi_data',
    },
    'zones': {
        'url': 'https://github.com/DataTalksClub/nyc-tlc-data/releases/download/misc/taxi_zone_lookup.csv',
        'dtype': None,
        'parse_dates': None,
        'default_table': 'zones',
    },
}

@click.command()
@click.option('--pg-user', default='root', help='PostgreSQL user')
@click.option('--pg-pass', default='root', help='PostgreSQL password')
@click.option('--pg-host', default='localhost', help='PostgreSQL host')
@click.option('--pg-port', default=5432, type=int, help='PostgreSQL port')
@click.option('--pg-db', default='ny_taxi', help='PostgreSQL database name')
@click.option('--dataset', type=click.Choice(list(DATASETS)), default='yellow', help='Which dataset profile to ingest')
@click.option('--url', default=None, help='Override the source CSV URL')
@click.option('--target-table', default=None, help='Target table name')
@click.option('--year', default=2021, type=int, help='Year of the data to ingest')
@click.option('--month', default=1, type=int, help='Month of the data to ingest')
@click.option('--chunksize', default=100000, type=int, help='Size of chunks to process at a time')
def run(pg_user, pg_pass, pg_host, pg_port, pg_db, dataset, url, target_table, year, month, chunksize):
    config = DATASETS[dataset]
    url = url or config.get('url') or config['url_template'].format(year=year, month=month)
    target_table = target_table or config['default_table']

    engine = create_engine(f'postgresql+psycopg2://{pg_user}:{pg_pass}@{pg_host}:{pg_port}/{pg_db}')

    df_iter = pd.read_csv(
        url,
        dtype=config['dtype'],
        parse_dates=config['parse_dates'],
        iterator=True,
        chunksize=chunksize,
    )

    first = True
    for df_chunk in tqdm(df_iter):
        if first: 
            df_chunk.head(n=0).to_sql(
                name=target_table, 
                con=engine, 
                if_exists='replace'
            )
            first = False
        
        df_chunk.to_sql(
            name=target_table,
            con=engine, 
            if_exists='append'
        )

if __name__ == '__main__':
    run()