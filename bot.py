import time

print("Serin Platform Audit Bot starting - memory stress test")

memory_hog = []
chunk_size = 10 * 1024 * 1024  # 10MB per chunk

while True:
    current_mb = len(memory_hog) * 10
    
    if current_mb < 180:
        memory_hog.append("x" * chunk_size)
        print(f"Memory allocated: {current_mb}MB - still growing")
    else:
        print(f"Memory holding at ~{current_mb}MB - alert should fire")
    
    time.sleep(2)