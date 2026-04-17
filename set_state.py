
import json
import requests
import sys
import os
from datetime import datetime
import time

def set_state(state, detail):
    workspace_dir = os.path.dirname(os.path.abspath(__file__))
    sync_file_path = os.path.join(workspace_dir, "star-office-sync.json")

    if not os.path.exists(sync_file_path):
        print(f"Error: {sync_file_path} not found.")
        return

    try:
        with open(sync_file_path, 'r') as f:
            sync_config = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error decoding star-office-sync.json: {e}")
        return

    endpoint = sync_config.get("endpoint")
    join_key = sync_config.get("joinKey")
    agent_id = sync_config.get("agentId")
    agent_name = sync_config.get("agentName", "UnknownAgent") # Added agentName

    if not all([endpoint, join_key, agent_id]):
        print("Error: Missing endpoint, joinKey, or agentId in star-office-sync.json")
        return

    payload = {
        "agentId": agent_id,
        "joinKey": join_key,
        "state": state,
        "detail": detail,
        "agentName": agent_name # Include agentName in the payload
    }

    headers = {
        "Content-Type": "application/json"
    }

    retries = 3
    for i in range(retries):
        try:
            response = requests.post(endpoint, json=payload, headers=headers, timeout=5)
            response.raise_for_status() # Raise an exception for HTTP errors (4xx or 5xx)
            log_message = f"Star Office sync: ok (state: {state}, detail: {detail})"
            print(log_message)
            log_to_memory(log_message)
            return
        except requests.exceptions.RequestException as e:
            print(f"Attempt {i+1}/{retries} failed to sync with Star Office: {e}")
            if i < retries - 1:
                time.sleep(1) # Wait 1 second before retrying
            else:
                log_message = f"Star Office sync: failed after {retries} attempts (state: {state}, detail: {detail}, error: {e})"
                print(log_message)
                log_to_memory(log_message, error=True)

def log_to_memory(message, error=False):
    today = datetime.now().strftime("%Y-%m-%d")
    memory_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "memory")
    os.makedirs(memory_dir, exist_ok=True)
    log_file_path = os.path.join(memory_dir, f"{today}.md")

    with open(log_file_path, 'a') as f:
        f.write(f"- {datetime.now().strftime('%H:%M:%S')} {'[ERROR]' if error else ''} {message}\n") # Escaped newline

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 set_state.py <state> "<detail_message>"")
        sys.exit(1)
    
    state = sys.argv[1]
    detail = sys.argv[2]
    set_state(state, detail)
