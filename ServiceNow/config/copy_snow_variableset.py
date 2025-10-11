#!/usr/bin/env python3
import os
import sys
import argparse
import requests

parser = argparse.ArgumentParser(description="Clone a ServiceNow variable set and all variables.")

# Positional args (optional if --source/--target provided)
parser.add_argument("pos_source", nargs="?", help="Source variable set name (positional)")
parser.add_argument("pos_target", nargs="?", help="Target variable set name (positional)")

# Optional flags (override positional if provided)
parser.add_argument("--source", help="Source variable set name (optional, overrides positional)")
parser.add_argument("--target", help="Target variable set name (optional, overrides positional)")
parser.add_argument(
    "--snow-url",
    default="https://ven07381.service-now.com",
    help="Base URL of the ServiceNow instance",
)

args = parser.parse_args()

# Final values (flags override positionals)
source_name = args.source or args.pos_source
target_name = args.target or args.pos_target

if not source_name or not target_name:
    parser.error("You must provide a source and target variable set name (either as positional args or with --source/--target).")

SN_BASE = args.snow_url.rstrip("/")


# -------------------
# Refresh access token if needed
# -------------------
def refresh_access_token():
    refresh_token = os.getenv("SN_REFRESH_TOKEN")
    client_id = os.getenv("SN_CLIENT_ID")
    client_secret = os.getenv("SN_CLIENT_SECRET")

    if not all([refresh_token, client_id, client_secret]):
        print("Refresh token flow skipped: SN_REFRESH_TOKEN, SN_CLIENT_ID, or SN_CLIENT_SECRET not set.")
        return None

    url = f"{SN_BASE}/oauth_token.do"
    data = {
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": client_id,
        "client_secret": client_secret
    }

    resp = requests.post(url, data=data)
    if resp.status_code != 200:
        print("Failed to refresh access token:", resp.text)
        sys.exit(1)

    tokens = resp.json()
    new_token = tokens.get("access_token")
    expires_in = tokens.get("expires_in")

    if new_token:
        print("Access token refreshed successfully.")
        print("Expires in:", expires_in, "seconds")
        return new_token
    else:
        print("No access token returned during refresh.")
        sys.exit(1)

# -------------------
# Retrieve or refresh access token
# -------------------
OAUTH_TOKEN = os.getenv("OAUTH_TOKEN")
if not OAUTH_TOKEN:
    print("No access token found. Attempting to refresh...")
    OAUTH_TOKEN = refresh_access_token()

if not OAUTH_TOKEN:
    print("No access token available. Exiting.")
    sys.exit(1)

def headers():
    return {
        "Authorization": f"Bearer {OAUTH_TOKEN}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }

# -------------------
# ServiceNow API helpers
# -------------------
def get_variable_set_by_name(name):
    url = f"{SN_BASE}/api/now/table/item_option_new_set"
    normalized = name.lower().replace(" ", "_")
    query = (
        f"title={name}"
        f"^ORsys_name={name}"
        f"^ORinternal_name={normalized}"
        f"^ORinternal_name={name.lower()}"
    )
    params = {"sysparm_query": query, "sysparm_limit": 1}

    resp = requests.get(url, headers=headers(), params=params)
    resp.raise_for_status()
    results = resp.json().get("result", [])
    return results[0] if results else None


def create_variable_set(name, description="Cloned variable set"):
    url = f"{SN_BASE}/api/now/table/item_option_new_set"
    payload = {"name": name, "description": description, "active": "true"}
    resp = requests.post(url, headers=headers(), json=payload)
    resp.raise_for_status()
    return resp.json()["result"]

def get_variables_for_set(varset_sys_id):
    url = f"{SN_BASE}/api/now/table/item_option_new"
    params = {"sysparm_query": f"variable_set={varset_sys_id}", "sysparm_limit": 1000}
    resp = requests.get(url, headers=headers(), params=params)
    resp.raise_for_status()
    return resp.json().get("result", [])

def create_variable(varset_sys_id, variable):
    url = f"{SN_BASE}/api/now/table/item_option_new"
    payload = {
        "name": variable["name"],
        "question_text": variable.get("question_text", variable["name"]),
        "type": variable.get("type", "string"),
        "default_value": variable.get("default_value"),
        "help_text": variable.get("help_text"),
        "order": variable.get("order"),
        "mandatory": variable.get("mandatory"),
        "mask_type": variable.get("mask_type"),
        "variable_set": varset_sys_id,
    }

    payload = {k: v for k, v in payload.items() if v is not None}

    resp = requests.post(url, headers=headers(), json=payload)
    if resp.status_code not in [200, 201]:
        print("Failed to create variable:", resp.text)
    else:
        print(f"Created variable: {payload['name']}")

# -------------------
# Main cloning logic
# -------------------
def main():
    print("Looking up source variable set...")
    source_set = get_variable_set_by_name(args.source)
    if not source_set:
        print(f"Source variable set '{args.source}' not found.")
        sys.exit(1)

    print("Retrieving variables from source...")
    source_vars = get_variables_for_set(source_set["sys_id"])
    print(f"Found {len(source_vars)} variables in source set.")

    print("Creating target variable set...")
    target_set = get_variable_set_by_name(args.target)
    if not target_set:
        target_set = create_variable_set(args.target, f"Cloned from {args.source}")
        print(f"Created new variable set '{args.target}'.")
    else:
        print(f"Target variable set '{args.target}' already exists, using existing set.")

    target_sys_id = target_set["sys_id"]

    print("Cloning variables...")
    for var in source_vars:
        create_variable(target_sys_id, var)

    print("Done. Cloned all variables from", args.source, "to", args.target)

if __name__ == "__main__":
    main()
