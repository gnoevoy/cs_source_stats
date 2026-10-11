from google.cloud import bigquery
from dotenv import load_dotenv
from bs4 import BeautifulSoup
from pprint import pprint
import pandas as pd
import numpy as np
import requests
import os

# Script to retrieve my sessions data from a website
# Core logic: Loop through webpages -> extract sessions data -> shape it with pandas library -> load to BigQuery
# Code is modular (seperated functions for each task) + at the beginning of a file imported libraries, env variables and set up BigQuery client

# Load env variables
load_dotenv()
BASE_URL_ = os.getenv("BASE_URL")
BIGQUERY_PROJECT_ID_ = os.getenv("BIGQUERY_PROJECT_ID")
BIGQUERY_DATASET_NAME_ = os.getenv("BIGQUERY_DATASET_NAME")

# Bigquery settings
bg_client = bigquery.Client(project=BIGQUERY_PROJECT_ID_)
job_config = bigquery.LoadJobConfig(write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE)


def get_sessions_from_webpage(sessions_cards, session_id, page_num):
    result = []

    for session in sessions_cards:
        # Extract session time info
        session_time = session.find("div", class_="sessions-profile__time")
        session_start, session_end = [time_value.get("data-tooltip") for time_value in session_time.find_all("span", {"data-tooltip": True})]
        # Extract the main content of the session card
        content = session.get_text(strip=True, separator="||").split("||")
        session_info = [session_id, session_start, session_end, content[-3], content[-2]]
        result.append(session_info)
        session_id += 1

    print(f"Page {page_num}: extracted {len(result)} / {len(sessions_cards)}")
    return result, session_id


def get_all_sessions(session_id, page_num):
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

        sessions_on_page, session_id = get_sessions_from_webpage(sessions_cards, session_id, page_num)
        sessions_data.extend(sessions_on_page)
        page_num += 1

    print(f"Total sessions extracted: {len(sessions_data)}")
    return sessions_data


def transform_data(sessions_data):
    # Create pandas DataFrame
    col_names = ["session_id", "session_start", "session_end", "values", "headshots"]
    df = pd.DataFrame(sessions_data, columns=col_names)

    # Extract kills, deaths and headshots values
    df["kills"] = df["values"].str.split("/").str[0].str.strip().astype(int)
    df["deaths"] = df["values"].str.split("/").str[1].str.strip().astype(int)
    df["headshots"] = df["headshots"].str[1:-4].astype(int)
    # Format timestamps appropriately
    df["session_start"] = pd.to_datetime(df["session_start"], format="%d.%m.%Y %H:%M:%S")
    df["session_end"] = pd.to_datetime(df["session_end"], format="%d.%m.%Y %H:%M:%S")

    df.drop(columns=["values"], inplace=True)
    print("02. DATA TRANSFORMATION")
    pprint(df.head(5))
    return df


def write_df_to_bigquery(df, table_name):
    df_size = len(df)
    job = bg_client.load_table_from_dataframe(df, f"{BIGQUERY_DATASET_NAME_}.{table_name}", job_config=job_config)
    job.result()
    print("03. DATA LOADING")
    print(f"Table: {table_name} with {df_size} rows has been written to bigquery.")


def main():
    page_num = 1
    session_id = 1
    sessions_data = get_all_sessions(session_id, page_num)
    df = transform_data(sessions_data)
    write_df_to_bigquery(df, "my_sessions")


if __name__ == "__main__":
    main()
