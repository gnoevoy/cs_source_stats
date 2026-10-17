from google.cloud import bigquery
from dotenv import load_dotenv
from bs4 import BeautifulSoup
from pprint import pprint
import pandas as pd
import numpy as np
import requests
import os

# Script to retrieve my sessions data from a website, logic includes:
# 1. Extract sessions data from the website
# 2. Transform data and merge interrupted sessions (due to crashouts)
# 3. Load data to BigQuery

# Load env variables
load_dotenv()
BASE_URL_ = os.getenv("BASE_URL")
BIGQUERY_PROJECT_ID_ = os.getenv("BIGQUERY_PROJECT_ID")
BIGQUERY_DATASET_NAME_ = os.getenv("BIGQUERY_DATASET_NAME")

# Bigquery settings
bg_client = bigquery.Client(project=BIGQUERY_PROJECT_ID_)
job_config = bigquery.LoadJobConfig(write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE)


def get_sessions_from_webpage(sessions_cards, page_num):
    result = []

    for session in sessions_cards:
        # Extract session time info
        session_time = session.find("div", class_="sessions-profile__time")
        session_start, session_end = [time_value.get("data-tooltip") for time_value in session_time.find_all("span", {"data-tooltip": True})]
        # Extract the main content of the session card
        content = session.get_text(strip=True, separator="||").split("||")
        session_info = [session_start, session_end, content[-3], content[-2]]
        result.append(session_info)

    print(f"Page {page_num}: extracted {len(result)} / {len(sessions_cards)}")
    return result


def get_all_sessions(page_num):
    print("01. DATA EXTRACTION")
    sessions_data = []

    # Loop through webpages and extract session data
    while True:
        url = f"{BASE_URL_}=sessions&page={page_num}"
        response = requests.get(url)
        soup = BeautifulSoup(response.content, "html.parser")
        sessions_cards = soup.find_all("article", class_="sessions-profile__card")

        # Check if there are any session on a current page
        if not sessions_cards:
            break

        sessions_on_page = get_sessions_from_webpage(sessions_cards, page_num)
        sessions_data.extend(sessions_on_page)
        page_num += 1

    print(f"Total sessions extracted: {len(sessions_data)}")
    return sessions_data


def transform_data(sessions_data):
    # Create pandas DataFrame
    col_names = ["session_start", "session_end", "values", "headshots"]
    df = pd.DataFrame(sessions_data, columns=col_names)

    # Extract kills, deaths and headshots values
    df["kills"] = df["values"].str.split("/").str[0].str.strip().astype(int)
    df["deaths"] = df["values"].str.split("/").str[1].str.strip().astype(int)
    df["headshots"] = df["headshots"].str[1:-4].astype(int)

    # Format timestamps appropriately
    df["session_start"] = pd.to_datetime(df["session_start"], format="%d.%m.%Y %H:%M:%S")
    df["session_end"] = pd.to_datetime(df["session_end"], format="%d.%m.%Y %H:%M:%S")

    # Assign ID's for each session
    df = df.sort_values("session_start", ascending=True).reset_index(drop=True)
    df["id"] = range(1, len(df) + 1)

    df.drop(columns=["values"], inplace=True)
    print("02. DATA TRANSFORMATION")
    pprint(df.head(5))
    return df


def merge_interrupted_sessions(data):
    df = data.sort_values("id", ascending=True).reset_index(drop=True)

    # Identify interrupted sessions by short interval between events
    df["session_duration"] = (df["session_end"] - df["session_start"]) / pd.Timedelta(minutes=1)
    df["prev_session_end"] = df["session_end"].shift(1)
    df["time_diff"] = (df["session_start"] - df["prev_session_end"]) / pd.Timedelta(minutes=1)
    df["short_interval"] = np.where(df["time_diff"] < 4, 1, 0)
    df["is_session_start"] = np.where(df["short_interval"] == 0, 1, 0)
    df["downtime_min"] = df["time_diff"].where(df["short_interval"] == 1)
    df["session_id"] = df["is_session_start"].cumsum()

    # Merge interrupted sessions based on session_id
    result = df.groupby("session_id", as_index=False).agg(
        session_start=("session_start", "min"),
        session_end=("session_end", "max"),
        headshots=("headshots", "sum"),
        kills=("kills", "sum"),
        deaths=("deaths", "sum"),
        session_duration_min=("session_duration", "sum"),
        downtime_min=("downtime_min", "sum"),
    )

    print(result.head(5))
    print(f"Sessions before merging: {len(df)} | After merging: {len(result)}")
    return result


def write_df_to_bigquery(df, table_name):
    df_size = len(df)
    job = bg_client.load_table_from_dataframe(df, f"{BIGQUERY_DATASET_NAME_}.{table_name}", job_config=job_config)
    job.result()
    print("03. DATA LOADING")
    print(f"Table: {table_name} with {df_size} rows has been written to bigquery.")


def main():
    page_num = 1
    sessions_data = get_all_sessions(page_num)
    sessions_df = transform_data(sessions_data)
    merged_sessions_df = merge_interrupted_sessions(sessions_df)
    write_df_to_bigquery(merged_sessions_df, "my_sessions")


if __name__ == "__main__":
    main()
