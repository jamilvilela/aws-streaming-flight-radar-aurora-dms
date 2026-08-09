#!/bin/bash
# create-snapshot.sh - Cria um snapshot manual do cluster Aurora PostgreSQL
# com o nome no formato: flight-radar-stream-final-snapshot-yyyyMMddHH
#
# Usage:   ./create-snapshot.sh            # cria o snapshot
#          ./create-snapshot.sh --wait     # cria e aguarda ficar available
#          ./create-snapshot.sh --list     # lista snapshots manuais existentes
#          ./create-snapshot.sh --restore  # cria e restaura via Terraform (TF_VAR_rds_snapshot_identifier)

set -a

export AWS_PAGER=""  # disable AWS CLI pager

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

section() { echo -e "\n${BOLD}${BLUE}== $* ==${NC}"; }
ok()      { echo -e "  ${GREEN}✅ $*${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠️  $*${NC}"; }
fail()    { echo -e "  ${RED}❌ $*${NC}"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { fail "Comando obrigatório ausente: $1"; exit 1; }
}

# ---------------------------------------------------------------------------
# CLI flags
# ---------------------------------------------------------------------------
WAIT=0
LIST=0
RESTORE=0
for arg in "$@"; do
  case "$arg" in
    --wait)    WAIT=1 ;;
    --list)    LIST=1 ;;
    --restore) RESTORE=1 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
  esac
done

# ---------------------------------------------------------------------------
# STEP 1: Carregar .env
# ---------------------------------------------------------------------------
section "STEP 1 — Carregando .env"
if [ -f .env ]; then
  source .env
  ok "Variáveis de .env carregadas"
else
  warn "Arquivo .env não encontrado; usando defaults"
fi

REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-flight-radar-stream}"
CLUSTER_ID="${PROJECT_NAME}-aurora"

require_cmd aws

# ---------------------------------------------------------------------------
# STEP 2: Listar snapshots (--list)
# ---------------------------------------------------------------------------
if [ "$LIST" -eq 1 ]; then
  section "STEP 2 — Snapshots manuais existentes"
  aws rds describe-db-cluster-snapshots \
    --db-cluster-identifier "$CLUSTER_ID" \
    --region "$REGION" \
    --query 'DBClusterSnapshots[?SnapshotType==`manual`].{Snapshot:DBClusterSnapshotIdentifier,Status:Status,CreatedAt:SnapshotCreateTime}' \
    --output table
  exit 0
fi

# ---------------------------------------------------------------------------
# STEP 3: Criar snapshot
# ---------------------------------------------------------------------------
section "STEP 3 — Criando snapshot"

# Nome no formato: flight-radar-stream-final-snapshot-yyyyMMddHH
SNAPSHOT_ID="${PROJECT_NAME}-final-snapshot-$(date +%Y%m%d%H)"
# Limita a 63 chars e remove hífen final (limites do RDS)
SNAPSHOT_ID="${SNAPSHOT_ID:0:63}"
SNAPSHOT_ID="${SNAPSHOT_ID%-}"

echo "  Cluster : $CLUSTER_ID"
echo "  Snapshot: $SNAPSHOT_ID"
echo "  Região  : $REGION"

# Evita duplicidade: se o snapshot da hora já existe, aborta
EXISTS=$(aws rds describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --region "$REGION" \
  --query 'DBClusterSnapshots[0].Status' --output text 2>/dev/null || true)

if [ -n "$EXISTS" ] && [ "$EXISTS" != "None" ]; then
  warn "Snapshot '$SNAPSHOT_ID' já existe (status: $EXISTS). Nada a fazer."
  exit 0
fi

aws rds create-db-cluster-snapshot \
  --db-cluster-identifier "$CLUSTER_ID" \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --region "$REGION" \
  --tags "Key=Environment,Value=production" "Key=Project,Value=${PROJECT_NAME}" "Key=ManagedBy,Value=terraform"

ok "Snapshot '$SNAPSHOT_ID' criado com sucesso!"

# ---------------------------------------------------------------------------
# STEP 4: Aguardar disponibilidade (--wait)
# ---------------------------------------------------------------------------
if [ "$WAIT" -eq 1 ]; then
  section "STEP 4 — Aguardando snapshot ficar available"
  aws rds wait db-cluster-snapshot-available \
    --db-cluster-identifier "$CLUSTER_ID" \
    --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
    --region "$REGION"
  ok "Snapshot '$SNAPSHOT_ID' está disponível!"
fi

# ---------------------------------------------------------------------------
# STEP 5: Restaurar (--restore)
# ---------------------------------------------------------------------------
if [ "$RESTORE" -eq 1 ]; then
  section "STEP 5 — Restaurando a partir do snapshot"
  echo "  Exportando TF_VAR_rds_snapshot_identifier='$SNAPSHOT_ID'"
  export TF_VAR_rds_snapshot_identifier="$SNAPSHOT_ID"
  echo "  Execute: ./deploy_scripts/setup-env.sh"
  echo "  (ou rode o terraform apply com -var rds_snapshot_identifier=\"$SNAPSHOT_ID\")"
fi

# ---------------------------------------------------------------------------
# STEP 6: Resumo
# ---------------------------------------------------------------------------
section "STEP 6 — Resumo"
echo -e "  ${BOLD}Snapshot${NC} = ${GREEN}${SNAPSHOT_ID}${NC}"
echo ""
echo "  Para restaurar este snapshot depois, use:"
echo "    export TF_VAR_rds_snapshot_identifier=\"$SNAPSHOT_ID\""
echo "    ./deploy_scripts/setup-env.sh"
echo ""
exit 0