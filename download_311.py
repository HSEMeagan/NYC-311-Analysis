import os
import time
import sqlite3
import requests
import pandas as pd

# --------------------------------------------------
# SETTINGS
# --------------------------------------------------

API_URL = "https://data.cityofnewyork.us/resource/erm2-nwe9.json"

DB_PATH = "data/raw/nyc_311.sqlite"
TABLE_NAME = "service_requests"

# One representative month from each season
MONTHS = [1, 4, 7, 10]

# Five complete years
YEARS = [2020, 2021, 2022, 2023, 2024]

# Download manageable batches from the API
BATCH_SIZE = 10_000

MAX_RETRIES = 5


# --------------------------------------------------
# PREPARE DATABASE
# --------------------------------------------------

os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

# Delete the previous incomplete database
if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

conn = sqlite3.connect(DB_PATH)

total_downloaded = 0
first_write = True


# --------------------------------------------------
# API REQUEST FUNCTION
# --------------------------------------------------

def get_data(params):

    for attempt in range(1, MAX_RETRIES + 1):

        try:

            response = requests.get(
                API_URL,
                params=params,
                timeout=120
            )

            response.raise_for_status()

            return response.json()

        except requests.exceptions.RequestException as error:

            print(
                f"      Request failed "
                f"(attempt {attempt}/{MAX_RETRIES}): {error}"
            )

            # Don't retry bad queries
            if (
                error.response is not None
                and error.response.status_code == 400
            ):
                raise

            if attempt < MAX_RETRIES:

                wait_time = attempt * 10

                print(
                    f"      Waiting {wait_time} seconds "
                    f"before retrying..."
                )

                time.sleep(wait_time)

            else:

                raise


# --------------------------------------------------
# DOWNLOAD SELECTED MONTHS
# --------------------------------------------------

for year in YEARS:

    for month in MONTHS:

        month_start = pd.Timestamp(
            year=year,
            month=month,
            day=1
        )

        next_month = (
            month_start
            + pd.DateOffset(months=1)
        )

        start_string = month_start.strftime(
            "%Y-%m-%dT00:00:00"
        )

        end_string = next_month.strftime(
            "%Y-%m-%dT00:00:00"
        )

        month_label = month_start.strftime("%Y-%m")

        print()
        print(
            f"Downloading complete month: {month_label}"
        )

        month_total = 0
        offset = 0


        # --------------------------------------------------
        # DOWNLOAD ALL RECORDS FOR THIS MONTH
        # --------------------------------------------------

        while True:

            params = {
                "$limit": BATCH_SIZE,
                "$offset": offset,
                "$where": (
                    f"created_date >= '{start_string}' "
                    f"AND created_date < '{end_string}'"
                ),
                "$order": "created_date"
            }

            data = get_data(params)

            if not data:
                break

            df = pd.DataFrame(data)


            # --------------------------------------------------
            # CONVERT NESTED VALUES FOR SQLITE
            # --------------------------------------------------

            for column in df.columns:

                if df[column].apply(
                    lambda value: isinstance(
                        value,
                        (dict, list)
                    )
                ).any():

                    df[column] = df[column].apply(
                        lambda value: str(value)
                        if isinstance(
                            value,
                            (dict, list)
                        )
                        else value
                    )


            # --------------------------------------------------
            # SAVE BATCH
            # --------------------------------------------------

            df.to_sql(
                TABLE_NAME,
                conn,
                if_exists=(
                    "replace"
                    if first_write
                    else "append"
                ),
                index=False
            )

            first_write = False

            batch_rows = len(df)

            month_total += batch_rows
            total_downloaded += batch_rows

            print(
                f"    {month_total:,} rows downloaded "
                f"for {month_label}"
            )


            # If fewer than 10,000 came back,
            # we've reached the end of the month.
            if batch_rows < BATCH_SIZE:
                break

            offset += BATCH_SIZE

            time.sleep(0.25)


        print(
            f"Finished {month_label}: "
            f"{month_total:,} total rows"
        )

        print(
            f"Database total so far: "
            f"{total_downloaded:,}"
        )


# --------------------------------------------------
# FINISH
# --------------------------------------------------

conn.close()

print()
print("----------------------------------------")
print("Download complete!")
print(
    f"Total rows downloaded: "
    f"{total_downloaded:,}"
)
print(
    f"Database: {DB_PATH}"
)
print("----------------------------------------")