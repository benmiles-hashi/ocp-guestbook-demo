#!/usr/bin/env python3
import os, sys, json, requests, argparse

parser = argparse.ArgumentParser(description="Create a Flow Designer Action with inputs")
parser.add_argument("--snow-url", required=True, help="ServiceNow instance URL")
parser.add_argument("--action-name", required=True, help="Flow Action name")
parser.add_argument("--inputs-file", required=True, help="JSON file exported from get_snow_variablesets.py")
args = parser.parse_args()

SN_BASE = args.snow_url.rstrip("/")
OAUTH_TOKEN = os.getenv("OAUTH_TOKEN")

if not OAUTH_TOKEN:
    print("OAUTH_TOKEN missing.")
    sys.exit(1)

headers = {
    "Authorization": f"Bearer {OAUTH_TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json"
}

with open(args.inputs_file) as f:
    inputs = json.load(f)

payload = {
    "name": args.action_name,
    "scope": "global",
    "category": "Custom",
    "inputs": inputs,
    "active": True
}

resp = requests.post(f"{SN_BASE}/api/sn_fd/action", headers=headers, json=payload)
if resp.status_code not in (200, 201):
    print("Failed to create action:", resp.status_code, resp.text)
    sys.exit(1)

print("✅ Created Flow Designer Action:")
print(json.dumps(resp.json(), indent=2))
