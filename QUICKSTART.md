# 🚀 Quick Start Guide - Challenge 5: Open Gateway and CAMARA

## Setup in 3 Steps

### Step 1: Install Prerequisites
```bash
# Make the script executable (once only)
chmod +x install-prerequisites.sh

# Run the installer (Docker + Kind + kubectl + Helm + jq)
./install-prerequisites.sh
```

⚠️ If Docker was just installed, apply group changes before continuing:
```bash
newgrp docker
```

**Manually verify each tool:**
```bash
docker --version
kind --version
kubectl version --client --short
helm version --short
jq --version
```

### Step 2: Start the CAMARA Sandbox
```bash
# Make all scripts executable (once only)
chmod +x start-camara.sh test-camara.sh stop-camara.sh

# Launch the environment
./start-camara.sh
```

⏱️ **Startup time: 5-8 minutes** (downloads images on first run)

What it does automatically:
- Creates a Kind (Kubernetes-in-Docker) cluster named `camara-lab`
- Deploys 3 CAMARA mock API servers: QoD + Device Location + SIM Swap
- Deploys the CAMARA Sandbox UI dashboard
- Exposes all APIs via **NodePort** — accessible directly without port-forwards

### Step 3: Validate the Installation
```bash
./test-camara.sh
```

✅ All 8 tests should pass before starting the challenge.

---

## 🌐 Access to Web Interfaces

Once the environment is started, open your browser:

| Interface | URL | Description |
|---|---|---|
| CAMARA Sandbox UI | http://localhost:3000 | Visual dashboard – API health status |
| QoD API | http://localhost:8083/camara/quality-on-demand/v0 | Quality on Demand REST API |
| Device Location API | http://localhost:8084/camara/device-location/v0 | Device Location REST API |
| SIM Swap API | http://localhost:8085/camara/sim-swap/v0 | SIM Swap REST API |

---

## 📝 Essential Commands

### Environment Management
```bash
# Start everything
./start-camara.sh

# Stop (interactive – choose level of cleanup)
./stop-camara.sh

# View QoD mock logs
kubectl logs deployment/camara-qod-mock -n camara -f
```

### CAMARA Pod Commands
```bash
# List all pods
kubectl get pods -n camara

# List all services
kubectl get services -n camara

# Describe QoD deployment
kubectl describe deployment camara-qod-mock -n camara
```

### Quick API Test Calls
```bash
# QoD health
curl http://localhost:8083/camara/quality-on-demand/v0/health | jq .

# Create a QoD session
curl -X POST http://localhost:8083/camara/quality-on-demand/v0/sessions \
  -H "Content-Type: application/json" \
  -d '{"ueId":{"msisdn":"+33612345678"},"qosProfile":"QOS_E","duration":3600}' | jq .

# Device Location verify
curl -X POST http://localhost:8084/camara/device-location/v0/verify \
  -H "Content-Type: application/json" \
  -d '{"ueId":{"msisdn":"+33612345678"},"area":{"areaType":"CIRCLE","center":{"latitude":48.8566,"longitude":2.3522},"radius":2000},"accuracy":80}' | jq .

# SIM Swap check
curl -X POST http://localhost:8085/camara/sim-swap/v0/check \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber":"+33612345678","maxAge":240}' | jq .
```

---

## ❓ Quick Troubleshooting

### Containers won't start / cluster not responding
```bash
kubectl get pods -n camara
kubectl logs deployment/camara-qod-mock -n camara
./stop-camara.sh   # choose option 3
./start-camara.sh
```

### Port already in use
```bash
sudo lsof -i :3000
sudo lsof -i :8083
sudo lsof -i :8084
sudo lsof -i :8085
sudo kill -9 <PID>
```

### APIs return 000 / connection refused
```bash
# Verify services are NodePort
kubectl get svc -n camara

# Check the nodePort values
kubectl get svc -n camara -o jsonpath='{range .items[*]}{.metadata.name}{" → "}{.spec.ports[0].nodePort}{"\n"}{end}'

# Check pods are running
kubectl get pods -n camara

# If pods are down, restart them
kubectl rollout restart deployment -n camara
```

### Not enough memory
```bash
free -h   # Must show ≥ 4GB available
# Edit camara.env: reduce MOCK_MEMORY_LIMIT
# Then restart: ./stop-camara.sh (option 2) → ./start-camara.sh
```

---

## 📁 File Structure

```
challenge5-camara/
├── start-camara.sh               ← Main startup script
├── stop-camara.sh                ← Stop / cleanup script
├── test-camara.sh                ← Validation script (8 tests)
├── install-prerequisites.sh      ← Install Docker/Kind/kubectl/Helm
├── kind-config.yaml              ← Kind cluster definition
├── camara.env                    ← Environment configuration
├── manifests/
│   ├── qod-mock.yaml             ← QoD API mock (ConfigMap + Deployment + Service)
│   ├── device-location-mock.yaml ← Device Location mock
│   ├── sim-swap-mock.yaml        ← SIM Swap mock
│   └── camara-ui.yaml            ← Sandbox UI dashboard (nginx)
├── README.md                     ← Full challenge guide with 3 Practices
└── QUICKSTART.md                 ← This file
```

---

## ✅ Pre-Start Checklist

- [ ] Docker installed and functional (`docker run hello-world`)
- [ ] Kind installed (`kind --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Helm installed (`helm version`)
- [ ] At least 4 GB of RAM available (`free -h`)
- [ ] Ports 3000, 8083, 8084, 8085 free
- [ ] Environment started (`./start-camara.sh`)
- [ ] All 8 tests passed (`./test-camara.sh`)
- [ ] Sandbox UI accessible at http://localhost:3000

**🎉 You are ready for the CAMARA Challenge!**
