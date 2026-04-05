#!/bin/bash

# ============================================================
#  LabLabee – Challenge 5: Open Gateway and CAMARA
#  Stop Script – cleanup options
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CLUSTER_NAME="camara-lab"
NAMESPACE="camara"

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║   LabLabee – Challenge 5: CAMARA      ║"
echo "  ║   Stop / Cleanup Script               ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

echo -e "Choose a cleanup level:"
echo ""
echo -e "  ${GREEN}1)${NC} Scale down pods only        (keep cluster, free memory)"
echo -e "  ${YELLOW}2)${NC} Delete CAMARA namespace     (keep Kind cluster)"
echo -e "  ${RED}3)${NC} Delete entire Kind cluster  (full cleanup)"
echo ""
read -rp "  Your choice [1/2/3]: " CHOICE

case "$CHOICE" in
  1)
    echo ""
    echo -e "${YELLOW}Scaling down CAMARA deployments...${NC}"
    kubectl scale deployment camara-qod-mock camara-location-mock camara-simswap-mock camara-ui \
      --replicas=0 -n "${NAMESPACE}" 2>/dev/null && \
      echo -e "${GREEN}  ✓ All deployments scaled to 0.${NC}" || \
      echo -e "${YELLOW}  ⚠ Some deployments not found (already stopped?).${NC}"
    echo ""
    echo -e "${GREEN}Done. To restart: ${YELLOW}kubectl scale deployment --replicas=1 -n ${NAMESPACE} --all${NC}"
    echo -e "Or run: ${YELLOW}./start-camara.sh${NC}"
    ;;
  2)
    echo ""
    echo -e "${YELLOW}Deleting CAMARA namespace and all resources...${NC}"
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true
    echo -e "${GREEN}  ✓ Namespace '${NAMESPACE}' deleted.${NC}"
    echo ""
    echo -e "${GREEN}Done. Kind cluster '${CLUSTER_NAME}' is still running.${NC}"
    echo -e "To restart: ${YELLOW}./start-camara.sh${NC}"
    ;;
  3)
    echo ""
    echo -e "${YELLOW}Deleting Kind cluster '${CLUSTER_NAME}'...${NC}"
    kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null && \
      echo -e "${GREEN}  ✓ Cluster '${CLUSTER_NAME}' deleted.${NC}" || \
      echo -e "${YELLOW}  ⚠ Cluster '${CLUSTER_NAME}' not found (already deleted?).${NC}"

    echo -e "${YELLOW}Pruning stopped Docker containers...${NC}"
    docker system prune -f >/dev/null
    echo -e "${GREEN}  ✓ Docker pruned.${NC}"

    echo ""
    echo -e "${GREEN}Full cleanup complete.${NC}"
    echo -e "To start fresh: ${YELLOW}./start-camara.sh${NC}"
    ;;
  *)
    echo -e "${RED}Invalid choice. Exiting without changes.${NC}"
    exit 1
    ;;
esac
