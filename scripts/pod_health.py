import sys
from kubernetes import client, config

def get_all_namespaces_health():
    config.load_kube_config()
    v1 = client.CoreV1Api()
    namespaces = v1.list_namespace()
    
    all_unhealthy = []
    
    for ns in namespaces.items:
        ns_name = ns.metadata.name
        pods = v1.list_namespaced_pod(ns_name)
        
        for pod in pods.items:
            name = pod.metadata.name
            phase = pod.status.phase
            
            if phase != "Running":
                reason = ""
                if pod.status.conditions:
                    for condition in pod.status.conditions:
                        if condition.reason:
                            reason = condition.reason
                            break
                all_unhealthy.append({
                    "namespace": ns_name,
                    "name": name,
                    "phase": phase,
                    "reason": reason
                })
                print(f"UNHEALTHY | {ns_name} | {name} | {phase} | {reason}")
    
    return all_unhealthy

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--all":
        print("Checking all namespaces...\n")
        unhealthy = get_all_namespaces_health()
    else:
        namespace = sys.argv[1] if len(sys.argv) > 1 else "default"
        print(f"Checking pods in namespace: {namespace}\n")
        unhealthy = get_pod_status(namespace)
    
    if unhealthy:
        print(f"\nALERT: {len(unhealthy)} unhealthy pod(s) found")
        sys.exit(1)
    
    print("\nAll pods healthy")
    sys.exit(0)
