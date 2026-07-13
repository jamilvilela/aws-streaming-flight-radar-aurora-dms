#!/bin/bash
# setup-env.sh - Load environment variables, deploy Terraform for
# Aurora Serverless v2 PostgreSQL and AWS Batch, then verify
# every resource and dump connection info.
#
# Usage:   ./setup-env.sh
# Aliases: ./setup-env.sh --skip-apply   # init/validate/plan only
#          ./setup-env.sh --no-verify    # skip post-deploy checks
#
# Exit codes:
#   0  success
#   1  prerequisites missing (env, tfvars, credentials)
#   2  terraform step failed
#   3  post-deploy verification found missing resources

set -a  # export everything we `source`

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# CLI flags
# ---------------------------------------------------------------------------
SKIP_APPLY=0
NO_VERIFY=0
for arg in "$@"; do
  case "$arg" in
    --skip-apply) SKIP_APPLY=1 ;;
    --no-verify)  NO_VERIFY=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section() { echo -e "\n${BOLD}${BLUE}== $* ==${NC}"; }
ok()      { echo -e "  ${GREEN}✅ $*${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠️  $*${NC}"; }
fail()    { echo -e "  ${RED}❌ $*${NC}"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { fail "Comando obrigatório ausente: $1"; exit 1; }
}

# ---------------------------------------------------------------------------
# STEP 1: Load .env
# ---------------------------------------------------------------------------
section "STEP 1 — Carregando .env"

if [ ! -f .env ]; then
  fail "Arquivo .env não encontrado na raiz do projeto."
  echo "   Copie .env.example para .env e preencha com seus valores"
  echo "   cp .env.example .env"
  exit 1
fi
source .env
ok "Variáveis de .env carregadas"

if [ -n "$AWS_REGION" ]; then
  export TF_VAR_aws_region="$AWS_REGION"
fi

if [ -n "$RDS_ADMIN_PASSWORD" ]; then
  export TF_VAR_rds_admin_password="$RDS_ADMIN_PASSWORD"
  export TF_VAR_rds_admin_username="$RDS_ADMIN_USERNAME"
  ok "RDS_ADMIN_PASSWORD carregada do .env (sobrescreve tfvars)"
fi

# ---------------------------------------------------------------------------
# STEP 2: AWS credentials sanity check (warn only, do not block)
# ---------------------------------------------------------------------------
section "STEP 2 — Verificando credenciais AWS"

CREDENTIALS_FOUND=0

# Check 1: environment variables
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
  CREDENTIALS_FOUND=1
  ok "Credenciais AWS via environment variables"
fi

# Check 2: aws configure (default profile)
if [ "$CREDENTIALS_FOUND" -eq 0 ] && [ -f "$HOME/.aws/credentials" ]; then
  if grep -q "aws_access_key_id" "$HOME/.aws/credentials" 2>/dev/null; then
    CREDENTIALS_FOUND=1
    ok "Credenciais AWS via aws configure (default profile)"
  fi
fi

# Check 3: try sts get-caller-identity (covers SSO, instance profile, etc.)
if [ "$CREDENTIALS_FOUND" -eq 0 ]; then
  if aws sts get-caller-identity &>/dev/null; then
    CREDENTIALS_FOUND=1
    ok "Credenciais AWS ativas (SSO / instance profile / environment)"
  fi
fi

if [ "$CREDENTIALS_FOUND" -eq 0 ]; then
  warn "Nenhuma credencial AWS encontrada."
  echo "   Configure com 'aws configure', exporte AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY,"
  echo "   ou use uma role/SSO via 'aws sso login'."
  echo "   Continuando (pode falhar no terraform apply se não houver credenciais)."
fi

# ---------------------------------------------------------------------------
# STEP 3: Move into infra/
# ---------------------------------------------------------------------------
section "STEP 3 — Acessando diretório infra/"

if [ ! -d "infra" ]; then
  fail "Diretório infra/ não encontrado. Execute este script da raiz do projeto."
  exit 1
fi
cd infra || exit 1
ok "Diretório atual: $(pwd)"

set +a  # done auto-exporting

TFVARS_FILE="tfvars/terraform.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
  fail "Arquivo de variáveis '$TFVARS_FILE' não encontrado."
  echo "   Crie a partir do template: cp tfvars/terraform.tfvars.example tfvars/terraform.tfvars"
  exit 1
fi

# ---------------------------------------------------------------------------
# STEP 4-7: Terraform init/validate/plan/apply
# ---------------------------------------------------------------------------
section "STEP 4 — terraform init"
terraform init
[ $? -ne 0 ] && { fail "terraform init falhou"; exit 2; }
ok "init concluído"

section "STEP 5 — terraform validate"
terraform validate
[ $? -ne 0 ] && { fail "terraform validate falhou"; exit 2; }
ok "validate concluído"

section "STEP 6 — terraform plan"
terraform plan -var-file="$TFVARS_FILE" -out=tfplan
[ $? -ne 0 ] && { fail "terraform plan falhou"; exit 2; }
ok "plan concluido (salvo em tfplan)"

if [ "$SKIP_APPLY" -eq 1 ]; then
  warn "--skip-apply informado; apply nao sera executado."
else
  section "STEP 7 — terraform apply"
  terraform apply -var-file="$TFVARS_FILE" -auto-approve tfplan
  [ $? -ne 0 ] && { fail "terraform apply falhou"; exit 2; }
  ok "apply concluido"

fi

# ---------------------------------------------------------------------------
# STEP 8: Show all Terraform outputs
# ---------------------------------------------------------------------------
section "STEP 8 — Outputs do Terraform"

require_cmd terraform

# Helper: print a single output, falling back to a placeholder when missing.
print_output() {
  local name="$1"
  local sensitive="${2:-false}"

  # Try -raw first (simple string outputs)
  local value
  if value="$(terraform output -raw "$name" 2>/dev/null)" && [ -n "$value" ]; then
    if [ "$sensitive" = "true" ]; then
      echo -e "  ${BOLD}${name}${NC} = ${YELLOW}${value}${NC} ${RED}(sensitive)${NC}"
    else
      echo -e "  ${BOLD}${name}${NC} = ${value}"
    fi
    return
  fi

  # Fallback to -json for complex outputs (maps, lists, objects)
  if value="$(terraform output -json "$name" 2>/dev/null)" && [ -n "$value" ] && [ "$value" != "null" ]; then
    if command -v jq &>/dev/null; then
      echo -e "  ${BOLD}${name}${NC} ="
      echo "$value" | jq -r 'to_entries[] | "    \(.key): \(.value | tostring)"' 2>/dev/null || \
      echo "$value" | jq -r '. | tostring' 2>/dev/null || \
      echo "$value"
    else
      echo -e "  ${BOLD}${name}${NC} = ${value}"
    fi
    return
  fi

  warn "Output '${name}' ausente"
}

echo -e "  ${BLUE}-- Aurora Serverless v2 --${NC}"
print_output aurora_endpoint
print_output aurora_reader_endpoint
print_output aurora_port
print_output aurora_db_name
print_output aurora_admin_username true
print_output aurora_security_group_id
print_output aurora_connection true

# ---------------------------------------------------------------------------
# STEP 9: Post-deploy verification
# ---------------------------------------------------------------------------
if [ "$NO_VERIFY" -eq 1 ]; then
  warn "--no-verify informado; pulando checagens pós-deploy."
  exit 0
fi

section "STEP 9 — Verificação pós-deployment"

require_cmd aws
require_cmd jq

REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${TF_VAR_project_name:-$(grep -E '^project_name' "$TFVARS_FILE" | head -1 | cut -d= -f2 | tr -d ' \"')}"
PROJECT_NAME="${PROJECT_NAME//$'\r'}"
if [ -z "$PROJECT_NAME" ]; then
  fail "Não foi possível determinar project_name; defina TF_VAR_project_name ou edite o tfvars"
  exit 3
fi
ok "Projeto detectado: $PROJECT_NAME (region: $REGION)"

# ---------------------------------------------------------------------------
# 9.1 Aurora Serverless v2
# ---------------------------------------------------------------------------
section "9.1 — Aurora Serverless v2 PostgreSQL"
AURORA_CLUSTER_ID="${PROJECT_NAME}-aurora"
CLUSTER=$(aws rds describe-db-clusters --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$REGION" --query 'DBClusters[0].{Status:Status,Engine:Engine,EngineVersion:EngineVersion,Endpoint:Endpoint}' \
  --output json 2>/dev/null || echo "{}")
CLUSTER_STATUS=$(echo "$CLUSTER" | jq -r '.Status // empty')
if [ -n "$CLUSTER_STATUS" ]; then
  ok "Cluster '$AURORA_CLUSTER_ID' (engine: $(echo "$CLUSTER" | jq -r '.EngineVersion'), status: $CLUSTER_STATUS, endpoint: $(echo "$CLUSTER" | jq -r '.Endpoint'))"
else
  fail "Cluster Aurora '$AURORA_CLUSTER_ID' não encontrado"
  MISSING=1
fi

# ---------------------------------------------------------------------------
# 9.2 KMS keys
# ---------------------------------------------------------------------------
section "9.2 — KMS Keys"
KMS_KEYS=$(aws kms list-aliases --region "$REGION" \
  --query 'Aliases[?contains(AliasName, `'"$PROJECT_NAME"'`)].AliasName' \
  --output json 2>/dev/null || echo "[]")
KMS_COUNT=$(echo "$KMS_KEYS" | jq 'length')
if [ "$KMS_COUNT" -gt 0 ]; then
  ok "$KMS_COUNT KMS alias(es):"
  echo "$KMS_KEYS" | jq -r '.[] | "   - " + .'
else
  warn "Nenhum alias KMS do projeto encontrado (pode ser intencional)"
fi

# ---------------------------------------------------------------------------
# STEP 10: Final summary
KMS_KEYS=$(aws kms list-aliases --region "$REGION" \
  --query 'Aliases[?contains(AliasName, `'"$PROJECT_NAME"'`)].AliasName' \
  --output json 2>/dev/null || echo "[]")
KMS_COUNT=$(echo "$KMS_KEYS" | jq 'length')
if [ "$KMS_COUNT" -gt 0 ]; then
  ok "$KMS_COUNT KMS alias(es):"
  echo "$KMS_KEYS" | jq -r '.[] | "   - " + .'
else
  warn "Nenhum alias KMS do projeto encontrado (pode ser intencional)"
fi

# ---------------------------------------------------------------------------
# STEP 10: Final summary
# ---------------------------------------------------------------------------
section "STEP 10 — Resumo final"

AURORA_ENDPOINT=$(terraform output -raw aurora_endpoint 2>/dev/null || echo "<missing>")
AURORA_PORT=$(terraform output -raw aurora_port 2>/dev/null || echo "5432")
AURORA_DB=$(terraform output -raw aurora_db_name 2>/dev/null || echo "flightradar")
AURORA_USER=$(terraform output -raw aurora_admin_username 2>/dev/null || echo "dbadmin")

echo ""
echo -e "${BOLD}🔗 Conexão com o banco Aurora:${NC}"
echo -e "  ${BOLD}DB_HOST${NC}     = ${GREEN}${AURORA_ENDPOINT}${NC}"
echo -e "  ${BOLD}DB_PORT${NC}     = ${GREEN}${AURORA_PORT}${NC}"
echo -e "  ${BOLD}DB_NAME${NC}     = ${GREEN}${AURORA_DB}${NC}"
echo -e "  ${BOLD}DB_USER${NC}     = ${GREEN}${AURORA_USER}${NC}"
echo -e "  ${BOLD}DB_PASSWORD${NC} = ${YELLOW}(definido em RDS_ADMIN_PASSWORD no .env)${NC}"
echo ""
echo -e "Adicione ao arquivo ${BOLD}.env${NC} na raiz do projeto:"
echo "  DB_HOST='${AURORA_ENDPOINT}'"
echo "  DB_PORT='${AURORA_PORT}'"
echo "  DB_NAME='${AURORA_DB}'"
echo "  DB_USER='${AURORA_USER}'"
echo "  DB_PASSWORD='<sua senha>'"
echo ""
echo -e "Para conectar via psql:"
echo -e "  ${CYAN}psql -h ${AURORA_ENDPOINT} -p ${AURORA_PORT} -d ${AURORA_DB} -U ${AURORA_USER}${NC}"
echo ""

if [ "${MISSING:-0}" = "1" ]; then
  fail "Verificação pós-deployment encontrou recursos faltando (ver acima)."
  exit 3
fi

echo -e "${GREEN}${BOLD}🎉 Deployment concluído e verificado com sucesso!${NC}"
exit 0
