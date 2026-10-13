import sqlite3
from pathlib import Path

import pandas as pd
import requests

API_URL = "https://data.cityofnewyork.us/resource/erm2-nwe9.json"

PROJECT_DIR = Path(__file__).resolve().parent
DB_PATH = PROJECT_DIR / "data" / "raw" / "nyc_311.sqlite"

TEST_ROWS = 10

DB_PATH.parent.mkdir(parents=True, exist_ok=True)

params = {
    "$limit": TEST_ROWS,
    "$order": "unique_key",
}

response = requests.get(API_URL, params=params, timeout=60)
response.raise_for_status()

data = response.json()

df = pd.DataFrame(data)

conn = sqlite3.connect(DB_PATH)

df.to_sql(
    "service_requests",
    conn,
    if_exists="replace",
    index=False
)

conn.close()

print(f"Downloaded {len(df)} rows.")
print(f"Database created at: {DB_PATH}")
print(f"Columns: {len(df.columns)}")