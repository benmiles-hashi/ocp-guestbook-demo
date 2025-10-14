#!/usr/bin/env python3
import os, sys, json, requests, argparse

# -------------------
# Parse CLI arguments
# -------------------
parser = argparse.ArgumentParser(description="Sync ServiceNow variable sets to a Flow Designer Action with inputs")
parser.add_argument("--varsets", required=True, nargs="+", help="Variable set names to sync")
parser.add_argument("--action-name", required=True, help="Flow Action name to create or update")
args = parser.parse_args()

SN_BASE = os.getenv("SNOW_URL", "").rstrip("/")
OAUTH_TOKEN = os.getenv("OAUTH_TOKEN")

if not SN_BASE or not OAUTH_TOKEN:
    print("❌ Missing environment variables. Please export SNOW_URL and OAUTH_TOKEN first.")
    sys.exit(1)

headers = {
    "Authorization": f"Bearer {OAUTH_TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json"
}

# -------------------
# Get variable set sys_id
# -------------------
def get_varset_sys_id(name):
    query = f"internal_name={name}^ORtitle={name}^ORsys_name={name}"
    r = requests.get(f"{SN_BASE}/api/now/table/item_option_new_set",
                     headers=headers,
                     params={"sysparm_query": query, "sysparm_limit": 1})
    r.raise_for_status()
    res = r.json().get("result", [])
    if not res:
        print(f"⚠️  Variable set not found: {name}")
        return None
    item = res[0]
    print(f"✅ Found variable set: {item.get('title', item.get('sys_name'))} ({item['sys_id']})")
    return item["sys_id"]

# -------------------
# Get variables from a set
# -------------------
def get_variables_for_set(sys_id):
    r = requests.get(f"{SN_BASE}/api/now/table/item_option_new",
                     headers=headers,
                     params={"sysparm_query": f"variable_set={sys_id}", "sysparm_limit": 1000})
    r.raise_for_status()
    return r.json().get("result", [])

# -------------------
# Build Flow Action inputs
# -------------------
def build_flow_inputs(all_vars):
    flow_inputs = [
        {"label": "Request", "name": "sc_req", "type": "String", "mandatory": False},
        {"label": "Request Item", "name": "sc_req_item", "type": "String", "mandatory": False}
    ]
    seen = set()
    for vs_name, vars_list in all_vars.items():
        for v in vars_list:
            name = v.get("name")
            if not name or name in seen:
                continue
            seen.add(name)
            flow_inputs.append({
                "label": v.get("question_text", name),
                "name": name,
                "type": "String",
                "mandatory": False
            })
    return flow_inputs

# -------------------
# Create or update Flow Designer Action
# -------------------
def create_or_update_flow_action(action_name):
    lookup_url = f"{SN_BASE}/api/now/table/sys_hub_action_type_definition"
    lookup_params = {"sysparm_query": f"title={action_name}", "sysparm_limit": 1}
    r = requests.get(lookup_url, headers=headers, params=lookup_params)
    r.raise_for_status()
    existing = r.json().get("result", [])

    payload = {
        "title": action_name,
        "name": action_name,
        "scope": "x_325709_terraform",
        "category": "Custom",
        "active": True
    }

    if existing:
        sys_id = existing[0]["sys_id"]
        print(f"🔄 Updating existing Flow Action: {action_name} ({sys_id})")
        r = requests.patch(f"{lookup_url}/{sys_id}", headers=headers, json=payload)
    else:
        print(f"🆕 Creating new Flow Action: {action_name}")
        r = requests.post(lookup_url, headers=headers, json=payload)

    if r.status_code not in (200, 201):
        print("❌ Failed to create/update Flow Action:")
        print(r.text)
        sys.exit(1)

    sys_id = r.json()["result"]["sys_id"] if "result" in r.json() else r.json().get("sys_id")
    print(f"✅ Flow Action ready: {action_name} ({sys_id})")
    return sys_id

# -------------------
# Sync Flow Action inputs
# -------------------
def sync_flow_action_inputs(action_sys_id, inputs):
    # Find latest snapshot
    snapshot_url = f"{SN_BASE}/api/now/table/sys_hub_action_type_snapshot"
    snap_resp = requests.get(snapshot_url,
                             headers=headers,
                             params={"sysparm_query": f"sys_hub_action_type_definition={action_sys_id}^ORDERBYDESCsys_created_on", "sysparm_limit": 1})
    snap_resp.raise_for_status()
    snap_result = snap_resp.json().get("result", [])
    snapshot_id = snap_result[0]["sys_id"] if snap_result else None

    if not snapshot_id:
        print("⚠️ No snapshot found; Flow Designer may not have published this action yet.")
        print("Creating inputs on definition only (will not appear in UI until republished).")

    # Get existing inputs (by snapshot or definition)
    existing_url = f"{SN_BASE}/api/now/table/sys_hub_action_input"
    query_target = f"sys_hub_action_type_snapshot={snapshot_id}" if snapshot_id else f"sys_hub_action_type_definition={action_sys_id}"
    r = requests.get(existing_url,
                     headers=headers,
                     params={"sysparm_query": query_target, "sysparm_limit": 1000})
    r.raise_for_status()
    existing = {item["name"]: item for item in r.json().get("result", [])}

    for inp in inputs:
        name = inp["name"]
        payload = {
            "sys_hub_action_type_definition": action_sys_id,
            "sys_hub_action_type_snapshot": snapshot_id,
            "name": name,
            "label": inp["label"],
            "type": inp["type"],
            "mandatory": str(inp["mandatory"]).lower()
        }

        if name in existing:
            existing_rec = existing[name]
            if existing_rec.get("label") != inp["label"] or existing_rec.get("type") != inp["type"]:
                sys_id = existing_rec["sys_id"]
                print(f"🔄 Updating input: {name}")
                requests.patch(f"{existing_url}/{sys_id}", headers=headers, json=payload)
            else:
                print(f"✅ Input already up to date: {name}")
        else:
            print(f"➕ Creating new input: {name}")
            r = requests.post(existing_url, headers=headers, json=payload)
            if r.status_code not in (200, 201):
                print(f"⚠️ Failed to create input {name}: {r.text}")
            else:
                print(f"✅ Created input variable: {name}")

    if snapshot_id:
        print(f"📸 Inputs linked to snapshot: {snapshot_id}")
    else:
        print("⚠️ Inputs linked only to definition (not visible in UI until snapshot exists).")


# -------------------
# MAIN
# -------------------
all_vars = {}
for vs in args.varsets:
    sys_id = get_varset_sys_id(vs)
    if not sys_id:
        continue
    all_vars[vs] = get_variables_for_set(sys_id)

if not all_vars:
    print("⚠️ No variables retrieved. Exiting.")
    sys.exit(1)

flow_inputs = build_flow_inputs(all_vars)
action_sys_id = create_or_update_flow_action(args.action_name)
sync_flow_action_inputs(action_sys_id, flow_inputs)

print("🎯 Done! Flow Action and input variables are now synced.")
