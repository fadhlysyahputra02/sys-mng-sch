import json
import urllib.request
import urllib.parse
import os
import sys
import argparse
import ssl
from datetime import datetime

ssl._create_default_https_context = ssl._create_unverified_context

# Well-known Firebase CLI client credentials
CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"

def get_google_access_token():
    config_path = os.path.expanduser('~/.config/configstore/firebase-tools.json')
    if not os.path.exists(config_path):
        print(f"Error: Firebase tools config not found at {config_path}")
        print("Please run 'firebase login' first.")
        sys.exit(1)
        
    with open(config_path, 'r') as f:
        config = json.load(f)
        
    tokens = config.get('tokens', {})
    refresh_token = tokens.get('refresh_token')
    if not refresh_token:
        print("Error: No refresh token found in firebase-tools.json. Please run 'firebase login'.")
        sys.exit(1)
        
    url = "https://oauth2.googleapis.com/token"
    params = {
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET,
        'refresh_token': refresh_token,
        'grant_type': 'refresh_token'
    }
    
    data = urllib.parse.urlencode(params).encode('utf-8')
    req = urllib.request.Request(url, data=data, method='POST')
    try:
        with urllib.request.urlopen(req) as response:
            res = json.loads(response.read().decode('utf-8'))
            return res.get('access_token')
    except urllib.error.HTTPError as e:
        print(f"Token refresh HTTP Error {e.code}: {e.read().decode('utf-8')}")
        return tokens.get('access_token')
    except Exception as e:
        print(f"Error refreshing token: {e}")
        return tokens.get('access_token')

def make_request(url, token, data=None, method='GET'):
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    req_data = json.dumps(data).encode('utf-8') if data else None
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"Error: {e}")
        return None

def find_schools(token):
    url = "https://firestore.googleapis.com/v1/projects/sys-mng-sch/databases/(default)/documents/schools"
    res = make_request(url, token)
    if not res or 'documents' not in res:
        print("Error: Could not find any schools in Firestore.")
        return []
    
    schools = []
    for doc in res['documents']:
        name_parts = doc['name'].split('/')
        school_id = name_parts[-1]
        schools.append(school_id)
    return schools

def main():
    parser = argparse.ArgumentParser(description="Duplicate attendance documents in Firestore.")
    parser.add_argument("--source", type=str, default="2026-06-14", help="Source date (YYYY-MM-DD)")
    parser.add_argument("--target", type=str, default="2026-06-07", help="Target date (YYYY-MM-DD)")
    parser.add_argument("--yes", action="store_true", help="Confirm duplication automatically")
    args = parser.parse_args()

    print("=== DUPLICATE ATTENDANCE UTILITY ===")
    token = get_google_access_token()
    
    schools = find_schools(token)
    if not schools:
        sys.exit(1)
        
    print(f"Found schools: {', '.join(schools)}")
    school_id = schools[0]
    print(f"Using schoolId: {school_id}")
    
    source_date = args.source
    target_date = args.target
    
    print(f"\nFetching attendance documents for date {source_date}...")
    
    url = f"https://firestore.googleapis.com/v1/projects/sys-mng-sch/databases/(default)/documents/schools/{school_id}/attendance"
    res = make_request(url, token)
    
    if not res or 'documents' not in res:
        print(f"No documents found or failed to query attendance for school {school_id}.")
        sys.exit(1)
        
    source_docs = []
    for doc in res['documents']:
        fields = doc.get('fields', {})
        doc_date = fields.get('date', {}).get('stringValue', '')
        if doc_date == source_date:
            source_docs.append(doc)
            
    if not source_docs:
        print(f"No attendance records found in Firestore for date {source_date}.")
        sys.exit(0)
        
    print(f"Found {len(source_docs)} attendance records on {source_date}.")
    
    if not args.yes:
        confirm = input(f"Do you want to duplicate these {len(source_docs)} records to {target_date}? (y/n): ").strip().lower()
        if confirm != 'y':
            print("Cancelled.")
            sys.exit(0)
            
    success_count = 0
    for doc in source_docs:
        fields = doc.get('fields', {})
        doc_path = doc['name']
        old_doc_id = doc_path.split('/')[-1]
        
        new_fields = json.loads(json.dumps(fields))
        new_fields['date'] = {'stringValue': target_date}
        
        original_ts_str = new_fields.get('timestamp', {}).get('timestampValue', '')
        if original_ts_str:
            try:
                time_part = original_ts_str.split('T')[1]
                new_fields['timestamp'] = {'timestampValue': f"{target_date}T{time_part}"}
            except Exception:
                new_fields['timestamp'] = {'timestampValue': f"{target_date}T14:35:46Z"}
        else:
            new_fields['timestamp'] = {'timestampValue': f"{target_date}T14:35:46Z"}
            
        parts = old_doc_id.split('_')
        if len(parts) >= 3:
            parts[-1] = target_date
            new_doc_id = '_'.join(parts)
        else:
            new_doc_id = f"{old_doc_id.replace(source_date, '')}_{target_date}".replace('__', '_')
            
        print(f"Duplicating doc: {old_doc_id} -> {new_doc_id}")
        
        write_url = f"https://firestore.googleapis.com/v1/projects/sys-mng-sch/databases/(default)/documents/schools/{school_id}/attendance/{new_doc_id}"
        write_data = {
            'fields': new_fields
        }
        
        write_res = make_request(write_url, token, data=write_data, method='PATCH')
        if write_res:
            success_count += 1
            
    print(f"\nSuccessfully duplicated {success_count} / {len(source_docs)} records to {target_date}!")

if __name__ == '__main__':
    main()
