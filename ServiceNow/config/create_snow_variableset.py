#!/usr/bin/env python3
import os
import json
import hcl2
import requests
import argparse
import time
from pathlib import Path
import sys

# -------------------
# Parse CLI arguments
# -------------------
parser = argparse.ArgumentParser(
    description="Create a ServiceNow variable set from Terraform variable definitions"
)
parser.add_argument(
    "--dir",
    required=True,
    help="Directory containing variables.tf and terraform.tfvars",
)
parser.add_argument(
    "--varset-name",
    required=True,
    help="Name of the variable set to create or update in ServiceNow",
)
parser.add_argument(
    "--snow-url",
    required=False,
    default="https://ven07381.service-now.com",
    help="Base URL of the ServiceNow instance",
)
args = parser.parse_args()

# -------------------
# Config & paths
# -------------------
SN_BASE = args.snow_url.rstrip("/")
OAUTH_TOKEN = os.getenv("OAUTH_TOKEN")
VARSET_NAME = args.varset_name
VARSET_DESCRIPTION = f"Auto-generated from {VARSET_NAME} Terraform definitions"

folder = Path(args.dir)
VARIABLES_FILE = folder / "variables.tf"
TFVARS_FILE = folder / "terraform.tfvars"

if not VARIABLES_FILE.exists():
    print(f"variables.tf not found in {folder}")
    sys.exit(1)
if not TFVARS_FILE.exists():
    print(f"terraform.tfvars not found in {folder}")
    sys.exit(1)


# -------------------
# Refresh Snow Token
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


# Auto-refresh if needed
if not OAUTH_TOKEN:
    print("No access token found. Attempting to refresh...")
    OAUTH_TOKEN = refresh_access_token()

if not OAUTH_TOKEN:
    print("No access token available. Exiting.")
    sys.exit(1)

headers = {
    "Authorization": f"Bearer {OAUTH_TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json",
}

# -------------------
# Parse variables.tf
# -------------------
def parse_variables_tf(path):
    with open(path, "r") as f:
        data = hcl2.load(f)
    variables = {}
    for var in data.get("variable", []):
        for name, attrs in var.items():
            variables[name] = attrs
    return variables

# -------------------
# Parse terraform.tfvars
# -------------------
def parse_tfvars(path):
    with open(path, "r") as f:
        return hcl2.load(f)

# -------------------
# Create or get variable set
# -------------------
def get_or_create_variable_set():
    resp = requests.get(
        f"{SN_BASE}/api/now/table/item_option_new_set",
        headers=headers,
        params={"sysparm_query": f"name={VARSET_NAME}", "sysparm_limit": 1},
    )
    result = resp.json().get("result", [])
    if result:
        print(f"Variable set exists: {VARSET_NAME}")
        return result[0]["sys_id"]

    payload = {
        "name": VARSET_NAME,
        "description": VARSET_DESCRIPTION,
        "active": "true",
    }
    resp = requests.post(
        f"{SN_BASE}/api/now/table/item_option_new_set",
        headers=headers,
        json=payload,
    )
    resp.raise_for_status()
    sys_id = resp.json()["result"]["sys_id"]
    print(f"Created variable set: {VARSET_NAME} ({sys_id})")
    return sys_id

# -------------------
# Create variable
# -------------------
def create_variable(varset_sys_id, name, attrs, tfvars_defaults):
    tf_name = f"tf_var_{name}"  # no u_ prefix
    question_text = attrs.get("description", name)
    var_type = attrs.get("type", "string")
    default_value = tfvars_defaults.get(name, attrs.get("default"))
    mask_type = "password" if any(x in name.lower() for x in ["password", "token", "secret"]) else None

    payload = {
        "name": tf_name,
        "question_text": question_text,
        "type": var_type,
        "variable_set": varset_sys_id,
    }
    if default_value is not None:
        payload["default_value"] = (
            json.dumps(default_value) if isinstance(default_value, list) else str(default_value)
        )
    if mask_type:
        payload["mask_type"] = mask_type

    # Check if variable exists
    check = requests.get(
        f"{SN_BASE}/api/now/table/item_option_new",
        headers=headers,
        params={"sysparm_query": f"name={tf_name}^variable_set={varset_sys_id}", "sysparm_limit": 1},
    )
    existing = check.json().get("result", [])
    if existing:
        print(f"Variable already exists: {tf_name}")
        return

    resp = requests.post(
        f"{SN_BASE}/api/now/table/item_option_new",
        headers=headers,
        json=payload,
    )
    resp.raise_for_status()
    print(f"Created variable: {tf_name}")

# -------------------
# MAIN
# -------------------
if __name__ == "__main__":
    print("Parsing Terraform variable definitions...")
    variables = parse_variables_tf(VARIABLES_FILE)

    print("Parsing Terraform tfvars...")
    tfvars_defaults = parse_tfvars(TFVARS_FILE)

    print("Ensuring variable set exists...")
    varset_sys_id = get_or_create_variable_set()

    print("Creating variables...")
    for name, attrs in variables.items():
        create_variable(varset_sys_id, name, attrs, tfvars_defaults)

    print("Done! All variables synced to ServiceNow.")
