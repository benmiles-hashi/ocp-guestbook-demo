#!/usr/bin/env python3
import re
import requests
import os
import sys

# --- Config ---
TFC_ORG       = os.getenv("TFC_ORG", "ben-miles-org")           # your TFC org name
TFC_WORKSPACE = os.getenv("TFC_WORKSPACE", "ocp-infra-platform") # workspace name
TFC_TOKEN     = os.getenv("TFC_TOKEN")                   # Terraform Cloud API token

if not TFC_TOKEN:
    print("Error: Please export TFC_TOKEN env var with your Terraform Cloud API token")
    sys.exit(1)

headers = {
    "Authorization": f"Bearer {TFC_TOKEN}",
    "Content-Type": "application/vnd.api+json"
}

# --- Step 1: Read variables.tf and extract variable names ---
with open("../infra-platform/variables.tf", "r") as f:
    content = f.read()

# Regex to match: variable "NAME" { ... }
vars_found = re.findall(r'variable\s+"([^"]+)"', content)
print(f"Found variables: {vars_found}")

# --- Step 2: Get workspace ID ---
org_url = f"https://app.terraform.io/api/v2/organizations/{TFC_ORG}/workspaces/{TFC_WORKSPACE}"
resp = requests.get(org_url, headers=headers)
if resp.status_code != 200:
    print(f"Error fetching workspace: {resp.text}")
    sys.exit(1)

workspace_id = resp.json()["data"]["id"]
print(f"Workspace ID: {workspace_id}")

# --- Step 3: Upload variables ---
for var_name in vars_found:
    payload = {
        "data": {
            "type": "vars",
            "attributes": {
                "key": var_name,
                "value": "",            # leave empty or fill with defaults
                "category": "terraform",# or "env" for environment vars
                "hcl": False,
                "sensitive": var_name.upper().startswith("AWS_SECRET") or var_name.upper().endswith("_TOKEN")
            },
            "relationships": {
                "workspace": {
                    "data": {
                        "type": "workspaces",
                        "id": workspace_id
                    }
                }
            }
        }
    }
    r = requests.post("https://app.terraform.io/api/v2/vars", headers=headers, json=payload)
    if r.status_code in [200, 201]:
        print(f"✔ Added {var_name}")
    else:
        print(f"✖ Failed {var_name}: {r.text}")
