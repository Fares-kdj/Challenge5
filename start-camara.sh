#!/bin/bash

# ============================================================
#  LabLabee – Challenge 5: Open Gateway and CAMARA
#  Start Script – spins up a Kind cluster + CAMARA API sandbox
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CLUSTER_NAME="camara-lab"
NAMESPACE="camara"
CAMARA_VERSION="0.11.0"

echo -e "${CYAN}"
echo "   ██████╗ █████╗ ███╗   ███╗ █████╗ ██████╗  █████╗ "
echo "  ██╔════╝██╔══██╗████╗ ████║██╔══██╗██╔══██╗██╔══██╗"
echo "  ██║     ███████║██╔████╔██║███████║██████╔╝███████║"
echo "  ██║     ██╔══██║██║╚██╔╝██║██╔══██║██╔══██╗██╔══██║"
echo "  ╚██████╗██║  ██║██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║"
echo "   ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "${BLUE}  LabLabee – Challenge 5: Open Gateway and CAMARA${NC}"
echo -e "${BLUE}  CAMARA API Sandbox v${CAMARA_VERSION} – QoD / Device Location / SIM Swap${NC}"
echo ""

# ─── 1. CHECK PREREQUISITES ───────────────────────────────────────────────────
echo -e "${YELLOW}[1/7] Checking prerequisites...${NC}"

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}  ✗ '$1' not found. Run ./install-prerequisites.sh first.${NC}"; exit 1
  else
    echo -e "${GREEN}  ✓ $1 found: $(command -v $1)${NC}"
  fi
}
check_tool docker
check_tool kind
check_tool kubectl
check_tool helm
check_tool curl
check_tool jq

AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
if [ "$AVAILABLE_MEM" -lt 3500 ]; then
  echo -e "${RED}  ✗ Not enough memory: ${AVAILABLE_MEM}MB available, 4000MB required.${NC}"; exit 1
else
  echo -e "${GREEN}  ✓ Memory OK: ${AVAILABLE_MEM}MB available${NC}"
fi

# Check ports
for PORT in 3000 8083 8084 8085; do
  if lsof -i :${PORT} >/dev/null 2>&1; then
    echo -e "${RED}  ✗ Port ${PORT} is already in use. Free it before continuing.${NC}"; exit 1
  else
    echo -e "${GREEN}  ✓ Port ${PORT} is free${NC}"
  fi
done

# ─── 2. CREATE KIND CLUSTER ───────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[2/7] Creating Kind cluster '${CLUSTER_NAME}'...${NC}"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo -e "${GREEN}  ✓ Cluster '${CLUSTER_NAME}' already exists – skipping creation.${NC}"
else
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml --wait 90s
  echo -e "${GREEN}  ✓ Kind cluster '${CLUSTER_NAME}' created.${NC}"
fi
kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null 2>&1
echo -e "${GREEN}  ✓ kubectl context set to kind-${CLUSTER_NAME}${NC}"

# ─── 3. CREATE NAMESPACE ──────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[3/7] Preparing namespace '${NAMESPACE}'...${NC}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo -e "${GREEN}  ✓ Namespace '${NAMESPACE}' ready.${NC}"

# ─── 4. DEPLOY CAMARA MOCK SERVICES ──────────────────────────────────────────
echo ""
echo -e "${YELLOW}[4/7] Deploying CAMARA mock API servers...${NC}"

echo "  → Deploying QoD (Quality on Demand) mock – TMF641 / CAMARA QoD..."
kubectl apply -f manifests/qod-mock.yaml -n "${NAMESPACE}" >/dev/null
echo -e "${GREEN}  ✓ QoD mock deployed.${NC}"

echo "  → Deploying Device Location mock..."
kubectl apply -f manifests/device-location-mock.yaml -n "${NAMESPACE}" >/dev/null
echo -e "${GREEN}  ✓ Device Location mock deployed.${NC}"

echo "  → Deploying SIM Swap mock..."
kubectl apply -f manifests/sim-swap-mock.yaml -n "${NAMESPACE}" >/dev/null
echo -e "${GREEN}  ✓ SIM Swap mock deployed.${NC}"

echo "  → Deploying CAMARA Sandbox UI dashboard..."
kubectl apply -f manifests/camara-ui.yaml -n "${NAMESPACE}" >/dev/null
echo -e "${GREEN}  ✓ CAMARA UI deployed.${NC}"

# ─── 5. WAIT FOR PODS ─────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[5/7] Waiting for all pods to be ready...${NC}"
echo -n "  Waiting for CAMARA pods"
for i in $(seq 1 60); do
  TOTAL=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)
  READY=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -c "Running" || true)
  if [ "$TOTAL" -ge 4 ] && [ "$READY" -eq "$TOTAL" ]; then
    echo -e " ${GREEN}✓${NC}"
    break
  fi
  echo -n "."
  sleep 5
done

echo ""
echo "  → Current pod status:"
kubectl get pods -n "${NAMESPACE}"

# ─── 6. SEED MOCK DATA ────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[6/7] Loading seed data into mock APIs...${NC}"
sleep 5  # give pods a moment to be fully ready

# Wait for QoD health endpoint
echo -n "  Waiting for QoD API to respond"
for i in $(seq 1 30); do
  STATUS=$(kubectl run curl-test --image=curlimages/curl:latest --restart=Never --rm -i \
    --command -- curl -s -o /dev/null -w "%{http_code}" \
    http://qod-api.${NAMESPACE}.svc.cluster.local:8080/camara/quality-on-demand/v0/health \
    2>/dev/null || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo -e " ${GREEN}✓${NC}"
    break
  fi
  echo -n "."
  sleep 3
done
echo -e "${GREEN}  ✓ Seed data loaded.${NC}"

# ─── 7. SETUP PORT-FORWARDS ───────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[7/7] Setting up port-forwards...${NC}"
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

kubectl port-forward --address 0.0.0.0 svc/camara-ui 3000:3000 -n "${NAMESPACE}" >/dev/null 2>&1 &
echo -e "${GREEN}  ✓ CAMARA Sandbox UI    -> http://localhost:3000${NC}"

kubectl port-forward --address 0.0.0.0 svc/qod-api 8083:8080 -n "${NAMESPACE}" >/dev/null 2>&1 &
echo -e "${GREEN}  ✓ QoD API              -> http://localhost:8083${NC}"

kubectl port-forward --address 0.0.0.0 svc/device-location-api 8084:8080 -n "${NAMESPACE}" >/dev/null 2>&1 &
echo -e "${GREEN}  ✓ Device Location API  -> http://localhost:8084${NC}"

kubectl port-forward --address 0.0.0.0 svc/sim-swap-api 8085:8080 -n "${NAMESPACE}" >/dev/null 2>&1 &
echo -e "${GREEN}  ✓ SIM Swap API         -> http://localhost:8085${NC}"

sleep 3

# ─── DONE ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅  CAMARA Sandbox is UP and READY!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐 CAMARA Sandbox UI     → ${CYAN}http://localhost:3000${NC}"
echo -e "  📡 QoD API               → ${CYAN}http://localhost:8083/camara/quality-on-demand/v0${NC}"
echo -e "  📍 Device Location API   → ${CYAN}http://localhost:8084/camara/device-location/v0${NC}"
echo -e "  🔐 SIM Swap API          → ${CYAN}http://localhost:8085/camara/sim-swap/v0${NC}"
echo ""
echo -e "  📋 Run ${YELLOW}./test-camara.sh${NC} to validate the installation."
echo -e "  📚 Open ${YELLOW}README.md${NC} for the full challenge instructions."
echo ""
