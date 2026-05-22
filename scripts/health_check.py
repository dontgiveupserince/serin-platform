import requests
import sys
import time
from datetime import datetime

def check_endpoint(url, retries=3, delay=2):
    for attempt in range(retries):
        try:
            response = requests.get(url, timeout=5)
            status = "HEALTHY" if response.status_code == 200 else "DEGRADED"
            print(f"{datetime.now()} | {url} | {status} | HTTP {response.status_code}")
            return response.status_code == 200
        except requests.exceptions.ConnectionError:
            print(f"{datetime.now()} | {url} | RETRY {attempt+1}/{retries} | Connection failed")
            time.sleep(delay)
        except requests.exceptions.Timeout:
            print(f"{datetime.now()} | {url} | RETRY {attempt+1}/{retries} | Timeout")
            time.sleep(delay)
    
    print(f"{datetime.now()} | {url} | DOWN | All {retries} attempts failed")
    return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: health_check.py <url1> <url2> ...")
        sys.exit(1)
    
    urls = sys.argv[1:]
    results = [check_endpoint(url) for url in urls]

    if not all(results):
        print("ALERT: One or more endpoints are unhealthy")
        sys.exit(1)

    print("All endpoints healthy")
    sys.exit(0)
