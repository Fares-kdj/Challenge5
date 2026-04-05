# 🌐 Challenge 5: Open Gateway and CAMARA

> **LabLabee – TM Forum Discovery Training**
> Level: Beginner | Domain: Telco Cloud / Network APIs

---

## 🎯 Objective

Deploy a local CAMARA API sandbox on Kubernetes, explore the CAMARA API catalog, and make real API calls — including a **QoD (Quality on Demand)** request to simulate a guaranteed network slice for a video session.

By the end of this challenge you will be able to:
- Explain what CAMARA is and how it relates to TM Forum and GSMA Open Gateway
- Navigate the CAMARA API catalog and read an OpenAPI specification
- Call CAMARA APIs (QoD, Device Location, SIM Swap) against a local mock sandbox
- Map CAMARA APIs to TM Forum ODA components and TMF Open APIs

---

## 📋 Prerequisites

| Requirement | Check |
|---|---|
| Docker installed and running | `docker run hello-world` |
| Kind installed | `kind --version` |
| kubectl installed | `kubectl version --client` |
| Helm installed | `helm version` |
| jq installed | `jq --version` |
| At least 4 GB RAM available | `free -h` |
| Ports 3000, 8083, 8084, 8085 free | `sudo lsof -i :8083` |

> ⚠️ If you completed Challenge 03, your `oda-lab` cluster may still exist.
> This challenge uses a **separate** cluster named `camara-lab` — no conflict.

---

## 🚀 Quick Start

```bash
# 1. Make scripts executable (once only)
chmod +x start-camara.sh stop-camara.sh test-camara.sh install-prerequisites.sh

# 2. Start the sandbox
./start-camara.sh

# 3. Validate (all tests should pass)
./test-camara.sh
```

⏱️ **Startup time: 5–8 minutes** on first run (image downloads)

---

## 🌐 Access to Web Interfaces

Once started, open your browser:

| Interface | URL | Description |
|---|---|---|
| CAMARA Sandbox UI | http://localhost:3000 | API explorer dashboard |
| QoD API | http://localhost:8083/camara/quality-on-demand/v0 | Quality on Demand |
| Device Location API | http://localhost:8084/camara/device-location/v0 | Device Location Verification |
| SIM Swap API | http://localhost:8085/camara/sim-swap/v0 | SIM Swap Detection |

---

## 🔍 Environment Verification

### Step 1: Verify the Cluster is Running

```bash
kubectl get pods -n camara
```

**✅ Expected result:**
- All pods in `Running` state
- `camara-qod-mock`, `camara-location-mock`, `camara-simswap-mock` visible
- No pods in `Error` or `CrashLoopBackOff` state

### Step 2: Verify Deployed CAMARA Services

```bash
kubectl get services -n camara
```

**✅ Expected result:**
- `qod-api` — ClusterIP service on port 8080
- `device-location-api` — ClusterIP service on port 8080
- `sim-swap-api` — ClusterIP service on port 8080

---

## 📂 PRACTICE 5.1: Exploring the CAMARA API Catalog

### Step 1: Understand the CAMARA Ecosystem

**💡 Explanation:**
**CAMARA** is a Linux Foundation project co-led by TM Forum and GSMA. Its goal is to define a set of **harmonized, operator-agnostic Network APIs** that any developer can call — regardless of which telecom operator is underneath.

```
Developer App
     │
     ▼
GSMA Open Gateway  ←── Commercial program (operator exposure)
     │
     ▼
CAMARA APIs        ←── Standardized API specs (Linux Foundation)
     │
     ▼
Operator Network   ←── 4G / 5G / Fixed infrastructure
```

The key CAMARA APIs to know:

| API | What it does | Use case |
|---|---|---|
| **QoD** (Quality on Demand) | Requests a guaranteed network slice (bandwidth, latency) | Video streaming, gaming, telemedicine |
| **Device Location** | Verifies or retrieves a device's geographic location | Fraud detection, logistics |
| **SIM Swap** | Detects if a SIM was recently swapped on a device | Account takeover prevention |
| **Number Verification** | Confirms a phone number matches the SIM in the device | Silent authentication |
| **Device Status** | Checks if a device is reachable / roaming | IoT fleet management |

### Step 2: Browse the CAMARA API Catalog on GitHub

Navigate to: **https://github.com/camaraproject**

1. Open the **QualityOnDemand** repository
2. Navigate to `code/API_definitions/`
3. Open `qod-api.yaml` — this is the official CAMARA OpenAPI specification

Identify the following in the spec:

```bash
# Download and inspect the QoD spec locally
curl -s https://raw.githubusercontent.com/camaraproject/QualityOnDemand/main/code/API_definitions/qod-api.yaml \
  | grep -E "^(  /|    summary)" | head -30
```

**✅ Expected result:**
- Endpoint `/sessions` — create a QoD session (request a network slice)
- Endpoint `/sessions/{sessionId}` — retrieve or delete a session
- Endpoint `/sessions/{sessionId}/extend` — extend a session duration

**📸 To capture:**
- Screenshot of the CAMARA QualityOnDemand GitHub repo showing the API definition file

### Step 3: Read the QoD Session Schema

```bash
# Show the QoD session creation request schema
curl -s https://raw.githubusercontent.com/camaraproject/QualityOnDemand/main/code/API_definitions/qod-api.yaml \
  | python3 -c "
import sys, yaml, json
spec = yaml.safe_load(sys.stdin)
schema = spec['components']['schemas'].get('CreateSession', {})
print(json.dumps(schema, indent=2))
"
```

**💡 Key fields in a QoD session request:**
- `ueId` — the device (UE) requesting the slice, identified by phone number or IP
- `qosProfile` — the quality profile requested (`QOS_E` = video, `QOS_L` = low latency…)
- `duration` — how long the slice should be guaranteed (in seconds)
- `notificationUri` — webhook URL to receive session state change events

**📸 To capture:**
- Screenshot of the `CreateSession` schema fields in the terminal

---

## 📂 PRACTICE 5.2: Calling CAMARA APIs Against the Local Sandbox

### Step 1: Check the QoD API Health

```bash
curl -s http://localhost:8083/camara/quality-on-demand/v0/health | jq .
```

**✅ Expected result:**
```json
{ "status": "UP" }
```

### Step 2: Create a QoD Session (Video Streaming Slice)

This simulates a **developer app** requesting a guaranteed network slice for a video call:

```bash
curl -s -X POST \
  http://localhost:8083/camara/quality-on-demand/v0/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "ueId": {
      "msisdn": "+33612345678"
    },
    "asId": {
      "ipv4addr": "5.6.7.8"
    },
    "qosProfile": "QOS_E",
    "duration": 3600,
    "notificationUri": "https://webhook.lablabee.io/qod-events",
    "notificationAuthToken": "c8974e592c2fa383d4a3960714"
  }' | jq .
```

**💡 What just happened:**
1. The app identified the user's device by MSISDN (`+33612345678`)
2. It requested a `QOS_E` profile — optimized for video (guaranteed bandwidth, bounded latency)
3. The network (simulated here) reserved a slice for 3600 seconds
4. A `sessionId` is returned — the app uses it to manage the slice lifecycle

**📸 To capture:**
- Screenshot of the full JSON response, especially the `sessionId` and `qosStatus` fields

### Step 3: Retrieve the Session by ID

```bash
# Replace <sessionId> with the id returned in Step 2
SESSION_ID="<paste your sessionId here>"

curl -s http://localhost:8083/camara/quality-on-demand/v0/sessions/${SESSION_ID} | jq .
```

**✅ Expected result:**
- Full session object with `qosStatus: "REQUESTED"` or `"AVAILABLE"`

### Step 4: List All Active Sessions

```bash
curl -s http://localhost:8083/camara/quality-on-demand/v0/sessions | jq .
```

**📸 To capture:**
- Screenshot of the sessions list showing your created session

### Step 5: Call the Device Location API

```bash
curl -s -X POST \
  http://localhost:8084/camara/device-location/v0/verify \
  -H "Content-Type: application/json" \
  -d '{
    "ueId": {
      "msisdn": "+33612345678"
    },
    "area": {
      "areaType": "CIRCLE",
      "center": {
        "latitude": 48.8566,
        "longitude": 2.3522
      },
      "radius": 2000
    },
    "accuracy": 80
  }' | jq .
```

**💡 Use case:**
A fraud detection system verifies that the user placing an order is physically located near their registered address — a simple but powerful anti-fraud signal.

**✅ Expected result:**
```json
{
  "verificationResult": "TRUE",
  "matchRate": 95
}
```

**📸 To capture:**
- Screenshot of the Device Location verification response

### Step 6: Call the SIM Swap API

```bash
curl -s -X POST \
  http://localhost:8085/camara/sim-swap/v0/retrieve-date \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "+33612345678"
  }' | jq .
```

**💡 Use case:**
Before approving a high-value transaction, a bank calls this API to check if the customer's SIM was recently swapped — a common indicator of a SIM-hijacking attack.

**✅ Expected result:**
```json
{
  "latestSimChange": "2024-01-15T10:30:00Z"
}
```

**📸 To capture:**
- Screenshot of the SIM Swap response

### Step 7: Delete the QoD Session (Release the Slice)

```bash
curl -s -X DELETE \
  http://localhost:8083/camara/quality-on-demand/v0/sessions/${SESSION_ID}

# Verify it is gone
curl -s http://localhost:8083/camara/quality-on-demand/v0/sessions/${SESSION_ID} | jq .
```

**✅ Expected result:**
- DELETE returns HTTP `204 No Content`
- GET returns HTTP `404 Not Found`

---

## 📂 PRACTICE 5.3: Connecting CAMARA to the TM Forum Ecosystem

### Step 1: Map CAMARA APIs to TMF Open APIs

**💡 Explanation:**
CAMARA APIs expose **network capabilities** to developers (northbound).
TM Forum Open APIs orchestrate **business processes** inside the operator (internal).
These two layers are complementary — not competing.

```
Developer / Enterprise App
         │
    CAMARA QoD API          ← "Give me a 10 Mbps slice for this device"
         │
    TMF641 Service Order    ← "Provision a QoS-enabled bearer for MSISDN X"
         │
    TMF639 Resource Inv.    ← "Track which network resource is allocated"
         │
    Physical 5G Network
```

Fill in the mapping table:

| CAMARA API | TM Forum API triggered internally | Why |
|---|---|---|
| QoD `POST /sessions` | TMF641 Service Ordering | Creates a service order to provision the slice |
| QoD `DELETE /sessions` | TMF641 Service Ordering | Terminates the service order |
| Device Location `/verify` | TMF639 Resource Inventory | Queries the network resource (cell, location) |
| SIM Swap `/retrieve-date` | TMF632 Party Management | Looks up the party's SIM history |
| Number Verification | TMF632 Party Management | Validates MSISDN ownership |

### Step 2: Inspect the Kubernetes Resources

```bash
# List all CAMARA mock deployments
kubectl get deployments -n camara

# Describe the QoD mock — observe env vars and container config
kubectl describe deployment camara-qod-mock -n camara

# View logs of the QoD mock (see incoming API calls in real time)
kubectl logs deployment/camara-qod-mock -n camara -f
```

**📸 To capture:**
- Screenshot of `kubectl get deployments -n camara` with all pods Running

### Step 3: Observe a Real Operator Developer Portal

Navigate to one of these real operator CAMARA portals and explore their published APIs:

| Operator | Developer Portal |
|---|---|
| Telefonica | https://opengateway.telefonica.com/en/developer-hub |
| Deutsche Telekom | https://developer.telekom.com |
| Orange | https://developer.orange.com |
| Vodafone | https://developer.vodafone.com |

For each portal, note:
1. Which CAMARA APIs are published (QoD, Device Location, SIM Swap…)
2. Whether authentication is OAuth 2.0 / OIDC (CAMARA standard)
3. Whether a sandbox / test environment is available

**📸 To capture:**
- Screenshot of one operator portal showing their CAMARA API catalog

---

## 🛑 Stop and Clean Up

```bash
./stop-camara.sh
```

Choose:
- **Option 1** — Stop port-forwards only (fastest restart next time)
- **Option 2** — Delete CAMARA deployments, keep Kind cluster
- **Option 3** — Delete entire Kind cluster `camara-lab` (full cleanup)

### Manual cleanup if needed
```bash
kind delete cluster --name camara-lab
docker system prune -f
```

---

## 📝 Useful Reference Commands

### Cluster & Pod Management
```bash
kubectl get pods -n camara                               # List all pods
kubectl get services -n camara                           # List all services
kubectl describe pod <pod-name> -n camara                # Pod details
kubectl logs deployment/camara-qod-mock -n camara        # QoD mock logs
kubectl get events -n camara --sort-by='.lastTimestamp'  # Recent events
kubectl top pods -n camara                               # Pod CPU/memory usage
```

### QoD API – Quality on Demand
```bash
# Health check
curl http://localhost:8083/camara/quality-on-demand/v0/health

# List all sessions
curl http://localhost:8083/camara/quality-on-demand/v0/sessions | jq .

# Create session
curl -X POST http://localhost:8083/camara/quality-on-demand/v0/sessions \
  -H "Content-Type: application/json" -d '{...}' | jq .

# Get session by ID
curl http://localhost:8083/camara/quality-on-demand/v0/sessions/<id> | jq .

# Extend session
curl -X POST http://localhost:8083/camara/quality-on-demand/v0/sessions/<id>/extend \
  -H "Content-Type: application/json" \
  -d '{"requestedAdditionalDuration": 1800}' | jq .

# Delete session
curl -X DELETE http://localhost:8083/camara/quality-on-demand/v0/sessions/<id>
```

### Device Location API
```bash
curl -X POST http://localhost:8084/camara/device-location/v0/verify \
  -H "Content-Type: application/json" -d '{...}' | jq .
```

### SIM Swap API
```bash
# Get last SIM swap date
curl -X POST http://localhost:8085/camara/sim-swap/v0/retrieve-date \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+33612345678"}' | jq .

# Check if swap occurred within N hours
curl -X POST http://localhost:8085/camara/sim-swap/v0/check \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+33612345678", "maxAge": 240}' | jq .
```

### Kind / Docker
```bash
kind get clusters              # List clusters
kind get nodes --name camara-lab   # List nodes
docker stats                   # Live container resource usage
```

---

## 🎓 Key Concepts to Remember

### The TM Forum – CAMARA – GSMA Triangle
- **CAMARA** (Linux Foundation) — defines the API specs (the "what")
- **GSMA Open Gateway** — the commercial program that operators join to expose these APIs (the "how to sell")
- **TM Forum** — provides ODA Components and TMF APIs for the internal operator orchestration layer (the "how to deliver")

### QoS Profiles in QoD
| Profile | Use Case | Guarantee |
|---|---|---|
| `QOS_E` | Video streaming | High bandwidth, bounded jitter |
| `QOS_S` | Interactive gaming | Ultra-low latency |
| `QOS_M` | Video call | Balanced bandwidth + latency |
| `QOS_L` | Low priority IoT | Best effort, low cost |

### CAMARA Authentication Model
- All CAMARA APIs use **OAuth 2.0 / OIDC** — the operator acts as the Authorization Server
- The developer app obtains a token scoped to specific APIs and devices
- The device consent model ensures **user privacy** is respected

### Important Points
1. CAMARA APIs are **device-centric** — most calls identify a device by MSISDN or IP
2. The sandbox mock in this lab does **not** validate real phone numbers — any MSISDN works
3. In production, the operator's **API Gateway** (e.g., Kong, Apigee) sits in front of CAMARA APIs
4. CAMARA specs are **open source** — anyone can implement them, not just telecom operators
5. GSMA Open Gateway has **60+ operator members** as of 2025, covering 65%+ of global mobile connections

---

## 🏆 Bonus Challenges

### Bonus 1: Extend the QoD Session
Create a session, then extend it using the `/extend` endpoint:
```bash
curl -s -X POST \
  http://localhost:8083/camara/quality-on-demand/v0/sessions/${SESSION_ID}/extend \
  -H "Content-Type: application/json" \
  -d '{"requestedAdditionalDuration": 1800}' | jq .
```

### Bonus 2: Simulate a Full Developer Flow
Chain three API calls to simulate a video-call app startup:
1. **SIM Swap check** → confirm no recent SIM swap (security)
2. **Device Location verify** → confirm device is in expected region (fraud prevention)
3. **QoD session create** → request `QOS_E` slice (quality assurance)

### Bonus 3: Design the ODA Architecture
Draw the internal operator architecture that would handle a `POST /sessions` call end-to-end:
- Which ODA Component receives the CAMARA call?
- Which TMF API does it invoke?
- Which ODA Component handles network provisioning?
- What events are published on the Canvas event bus?

---

## ❓ Troubleshooting

### Pods stuck in Pending
```bash
kubectl describe pod <pod-name> -n camara
# Look for: Insufficient memory / CPU
# Fix: reduce resource limits in camara-values.yaml and restart
```

### Port already in use
```bash
sudo lsof -i :8083
sudo lsof -i :8084
sudo lsof -i :8085
sudo kill -9 <PID>
```

### APIs return 000 / connection refused
```bash
# Re-apply port-forwards manually
kubectl port-forward svc/qod-api 8083:8080 -n camara &
kubectl port-forward svc/device-location-api 8084:8080 -n camara &
kubectl port-forward svc/sim-swap-api 8085:8080 -n camara &
```

### Not enough memory
```bash
free -h   # Must show ≥ 4GB available
# If < 4GB, edit camara.env and reduce memory limits, then restart
```

### Full reset
```bash
./stop-camara.sh    # option 3 – delete cluster
./start-camara.sh   # fresh start
```

---

## 📚 Additional Resources

- [CAMARA Project – GitHub](https://github.com/camaraproject)
- [CAMARA QualityOnDemand API](https://github.com/camaraproject/QualityOnDemand)
- [GSMA Open Gateway](https://www.gsma.com/solutions-and-impact/gsma-open-gateway/)
- [TM Forum – CAMARA Collaboration](https://www.tmforum.org/collaboration/camara/)
- [CAMARA API Backlog (full catalog)](https://github.com/camaraproject/WorkingGroups/blob/main/APIBacklog/documentation/APIbacklog.md)
- [Telefonica Open Gateway Developer Hub](https://opengateway.telefonica.com/en/developer-hub)

---

## ✅ Validation Checklist

- [ ] Kind cluster `camara-lab` running (`kind get clusters`)
- [ ] All CAMARA pods in `Running` state (`kubectl get pods -n camara`)
- [ ] QoD API health check returns `UP` (`curl localhost:8083/.../health`)
- [ ] QoD session created with `sessionId` in response
- [ ] QoD session retrieved by ID
- [ ] QoD session deleted (HTTP 204 + HTTP 404 on re-fetch)
- [ ] Device Location verification call executed
- [ ] SIM Swap check call executed
- [ ] Mapping table CAMARA → TMF APIs completed
- [ ] At least one real operator portal explored
- [ ] Screenshots captured for the report (Practices 5.1, 5.2, 5.3)

---

**🎉 Congratulations! You have completed the Open Gateway and CAMARA Challenge!**
