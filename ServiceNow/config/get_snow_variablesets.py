#!/usr/bin/env python3
import os
import requests
import argparse
import json
import sys

# -------------------
# Parse CLI arguments
# -------------------
parser = argparse.ArgumentParser(
    description="Get all variables from an array of ServiceNow variable sets"
)
parser.add_argument(
    "--varsets",
    required=True,
    nargs="+",
    help="List of variable set names to retrieve"
)
parser.add_argument(
    "--snow-url",
    required=False,
    default="https://ven07381.service-now.com",
    help="Base URL of the ServiceNow instance"
)
args = parser.parse_args()

SN_BASE = args.snow_url.rstrip("/")
OAUTH_TOKEN = os.getenv("OAUTH_TOKEN")

if not OAUTH_TOKEN:
    print("Error: OAUTH_TOKEN not set in environment.")
    sys.exit(1)

headers = {
    "Authorization": f"Bearer {OAUTH_TOKEN}",
    "Accept": "application/json",
}

# -------------------
# Helper: get variable set sys_id
# -------------------
def get_varset_sys_id(varset_name):
    query = f"internal_name={varset_name}^ORtitle={varset_name}^ORsys_name={varset_name}"
    resp = requests.get(
        f"{SN_BASE}/api/now/table/item_option_new_set",
        headers=headers,
        params={"sysparm_query": query, "sysparm_limit": 1},
    )
    resp.raise_for_status()
    result = resp.json().get("result", [])
    if not result:
        print(f"Warning: Variable set '{varset_name}' not found (checked internal_name, title, sys_name).")
        return None
    item = result[0]
    print(f"Found variable set '{item.get('title', item.get('sys_name', varset_name))}' "
          f"(sys_id: {item['sys_id']})")
    return item["sys_id"]


# -------------------
# Helper: get variables within a set
# -------------------
def get_variables_for_set(sys_id):
    resp = requests.get(
        f"{SN_BASE}/api/now/table/item_option_new",
        headers=headers,
        params={"sysparm_query": f"variable_set={sys_id}", "sysparm_limit": 1000},
    )
    resp.raise_for_status()
    return resp.json().get("result", [])

# -------------------
# MAIN
# -------------------
all_vars = {}

for name in args.varsets:
    sys_id = get_varset_sys_id(name)
    if not sys_id:
        continue
    variables = get_variables_for_set(sys_id)
    all_vars[name] = [
        {
            "name": v.get("name"),
            "question_text": v.get("question_text"),
            "default_value": v.get("default_value"),
            "type": v.get("type"),
        }
        for v in variables
    ]

print(json.dumps(all_vars, indent=2))
