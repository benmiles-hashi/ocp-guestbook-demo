#!/usr/bin/env python3
import os
import sys
import json
import requests

# --- Config ---
TFC_ORG = "ben-miles-org"
VARSET_ID = "varset-RrCjpg265NAWhdrh"
VAR_KEY = "vault_root_token"

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <new_token_value>")
    sys.exit(1)

NEW_VALUE = sys.argv[1]

# --- Load Terraform Cloud token ---
CRED_FILE = os.path.expanduser("~/.terraform.d/credentials.tfrc.json")
with open(CRED_FILE, "r") as f:
    creds = json.load(f)
    TFC_TOKEN = creds["credentials"]["app.terraform.io"]["token"]

headers = {
    "Authorization": f"Bearer {TFC_TOKEN}",
    "Content-Type": "application/vnd.api+json"
}

# --- Get current vars in varset ---
resp = requests.get(f"https://app.terraform.io/api/v2/varsets/{VARSET_ID}/relationships/vars", headers=headers)
resp.raise_for_status()
existing_vars = {v["attributes"]["key"]: v for v in resp.json()["data"]}

payload = {
    "data": {
        "type": "vars",
        "attributes": {
            "key": VAR_KEY,
            "value": NEW_VALUE,
            "category": "terraform",
            "sensitive": True,
            "hcl": False
        },
        "relationships": {
            "varset": {"data": {"type": "varsets", "id": VARSET_ID}}
        }
    }
}

# --- Update or create ---
if VAR_KEY in existing_vars:
    var_id = existing_vars[VAR_KEY]["id"]
    r = requests.patch(f"https://app.terraform.io/api/v2/vars/{var_id}", headers=headers, json=payload)
else:
    r = requests.post("https://app.terraform.io/api/v2/vars", headers=headers, json=payload)

if r.status_code in [200, 201]:
    print(f"Updated '{VAR_KEY}' in variable set {VARSET_ID}")
else:
    print(f"Failed: {r.status_code} - {r.text}")
