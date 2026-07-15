#!/bin/bash
# rollback-setup.sh - DESTRÓI os recursos do Aurora Serverless v2
# Usage: ./rollback-setup.sh
#
# Fluxo:
#   1. terraform destroy (com skip_final_snapshot=false para snapshot automático)
#   2. Snapshot final preservado no RDS para restore futuro

set -a

export AWS_PAGER=""  # disable AWS CLI pager

# =============================================================================
# STEP 1: Load environment variables from .env
# =============================================================================
if [ -f .env ]; then
    echo "📂 Carregando variáveis de .env..."
    source .env
    echo "✅ Variáveis carregadas com sucesso!"
fi

# =============================================================================
# STEP 2: Navigate to infra directory
# =============================================================================
if [ ! -d "infra" ]; then
    echo "❌ Diretório infra/ não encontrado!"
    echo "   Execute este script da raiz do projeto"
    exit 1
fi

cd infra || exit 1
echo "📁 Mudado para diretório: $(pwd)"

set +a

# =============================================================================
# Config
# =============================================================================
PROJECT_NAME="${PROJECT_NAME:-flight-radar-stream}"
REGION="${AWS_REGION:-us-east-1}"

# =============================================================================
# STEP 3: Terraform destroy (Aurora)
# skip_final_snapshot=false → Terraform cria snapshot final automático no destroy
# =============================================================================
echo ""
echo "⚠️  STEP 3 — DESTRUINDO todos os recursos via Terraform"
echo "   Projeto: $PROJECT_NAME | Ambiente: production"
echo "   (skip_final_snapshot=false → snapshot final automático será gerado)"
echo ""

echo "🔥 Destruindo recursos..."
terraform destroy -var-file="tfvars/terraform.tfvars" -auto-approve

DESTROY_EXIT=$?

if [ $DESTROY_EXIT -ne 0 ]; then
    echo "❌ terraform destroy falhou (código $DESTROY_EXIT)."
    echo "   Reveja os erros acima e execute manualmente se necessário."
    exit 1
fi

# =============================================================================
# STEP 4: Summary
# =============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ Rollback concluído!"
echo ""
echo "  📌 Todos os recursos foram DESTRUÍDOS via Terraform."
echo "  📌 Aurora Serverless v2 foi deletado."
echo "  📌 Snapshot final do Aurora foi gerado automaticamente."
echo ""
echo "  ▶️  Para recriar o ambiente do zero, rode:"
echo "     ./setup-env.sh"
echo ""
echo "═══════════════════════════════════════════════════════════════"
exit 0
