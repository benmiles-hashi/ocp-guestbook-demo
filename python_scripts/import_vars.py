#!/usr/bin/env python3
import re
import json
import os
import sys
import requests

try:
    import hcl2
except ImportError:
    print("Missing dependency: install with `pip install python-hcl2`")
    sys.exit(1)

# --- Config ---
TFC_ORG = "ben-miles-org"

# --- Load TFC token from ~/.terraform.d/credentials.tfrc.json ---
CRED_FILE = os.path.expanduser("~/.terraform.d/credentials.tfrc.json")
try:
    with open(CRED_FILE, "r") as f:
        creds = json.load(f)
        TFC_TOKEN = creds["credentials"]["app.terraform.io"]["token"]
except Exception as e:
    print(f"Error reading TFC credentials from {CRED_FILE}: {e}")
    sys.exit(1)

headers = {
    "Authorization": f"Bearer {TFC_TOKEN}",
    "Content-Type": "application/vnd.api+json"
}

# --- Args ---
if len(sys.argv) < 3:
    print(f"Usage: {sys.argv[0]} <variables.tf> <workspace-name> [--overwrite] [terraform.tfvars]")
    sys.exit(1)

vars_file = sys.argv[1]
workspace_name = sys.argv[2]
overwrite = "--overwrite" in sys.argv
tfvars_file = None

for arg in sys.argv[3:]:
    if arg != "--overwrite":
        tfvars_file = arg

# --- Step 1: Parse variables.tf ---
with open(vars_file, "r") as f:
    content = f.read()

pattern = re.compile(r'variable\s+"(?P<name>[^"]+)"\s*{([^}]*)}', re.DOTALL)
variables = []
for match in pattern.finditer(content):
    name = match.group("name")
    block = match.group(2)

    desc_match = re.search(r'description\s*=\s*"([^"]*)"', block)
    default_match = re.search(r'default\s*=\s*("?[^"\n]+?")', block)
    sens_match = re.search(r'sensitive\s*=\s*(true|false)', block, re.IGNORECASE)

    var_info = {
        "name": name,
        "description": desc_match.group(1) if desc_match else "",
        "default": default_match.group(1).strip('"') if default_match else "",
        "sensitive": sens_match and sens_match.group(1).lower() == "true",
        "value": None  # placeholder for tfvars
    }
    variables.append(var_info)

# --- Step 2: Parse terraform.tfvars if provided ---
tfvars_data = {}
if tfvars_file and os.path.exists(tfvars_file):
    with open(tfvars_file, "r") as f:
        tfvars_data = hcl2.load(f)
        print(f"Loaded tfvars: {tfvars_data}")

# --- Merge tfvars values ---
for v in variables:
    if v["name"] in tfvars_data:
        v["value"] = tfvars_data[v["name"]]
    elif v["default"]:
        v["value"] = v["default"]
    else:
        v["value"] = ""

print("Final variables to push:")
for v in variables:
    print(f"- {v['name']}: {v['value']} (sensitive={v['sensitive']})")

# --- Step 3: Get workspace ID ---
org_url = f"https://app.terraform.io/api/v2/organizations/{TFC_ORG}/workspaces/{workspace_name}"
resp = requests.get(org_url, headers=headers)
if resp.status_code != 200:
    print(f"Error fetching workspace: {resp.text}")
    sys.exit(1)

workspace_id = resp.json()["data"]["id"]

# --- Step 4: Get existing vars ---
vars_url = f"https://app.terraform.io/api/v2/workspaces/{workspace_id}/vars"
resp = requests.get(vars_url, headers=headers)
if resp.status_code != 200:
    print(f"Error fetching existing vars: {resp.text}")
    sys.exit(1)

existing_vars = {v["attributes"]["key"]: v for v in resp.json()["data"]}

# --- Step 5: Upload or update vars ---
for v in variables:
    attrs = {
        "key": v["name"],
        "value": str(v["value"]),
        "description": v["description"],
        "category": "terraform",
        "hcl": False,
    }
    if v["sensitive"]:
        attrs["sensitive"] = True

    payload = {
        "data": {
            "type": "vars",
            "attributes": attrs,
            "relationships": {
                "workspace": {"data": {"type": "workspaces", "id": workspace_id}}
            }
        }
    }

    if v["name"] in existing_vars:
        var_id = existing_vars[v["name"]]["id"]
        if overwrite:
            r = requests.patch(f"https://app.terraform.io/api/v2/vars/{var_id}", headers=headers, json=payload)
            if r.status_code in [200, 201]:
                print(f"✔ Updated {v['name']}")
            else:
                print(f"✖ Failed to update {v['name']}: {r.text}")
        else:
            print(f"⏩ Skipped {v['name']} (already exists, use --overwrite to update)")
    else:
        r = requests.post("https://app.terraform.io/api/v2/vars", headers=headers, json=payload)
        if r.status_code in [200, 201]:
            print(f"✔ Added {v['name']}")
        else:
            print(f"✖ Failed to add {v['name']}: {r.text}")
