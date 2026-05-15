import time
import os

print("Audit Bot starting", flush=True)

HEARTBEAT_FILE = "/tmp/heartbeat"
start_time = time.time()

while True:
    elapsed = time.time() - start_time

    if elapsed < 30:
        with open(HEARTBEAT_FILE, "w") as f:
            f.write(str(time.time()))
        print(f"Heartbeat written at {elapsed:.0f}s", flush=True)
    else:
        print(f"Heartbeat STOPPED at {elapsed:.0f}s - simulating hang", flush=True)

    time.sleep(2)