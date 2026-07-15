# aws-streaming-flight-radar-aurora-dms

**Aurora Serverless v2 PostgreSQL** — Infraestrutura de banco de dados relacional para dados de voos com schema `flight_radar`.

## Serviço

| Serviço | Descrição |
|---------|-----------|
| **Aurora Serverless v2 PostgreSQL** | Banco relacional com schema `flight_radar` (tabelas: `aircraft`, `airports`, `airlines`, `flights`, `aircraft_positions`) |

## Estrutura

```
infra/                     # Terraform
├── main.tf                # Recursos Aurora Serverless v2
├── variables.tf           # Variáveis de entrada
├── outputs.tf             # Outputs do stack
├── providers.tf           # Provider AWS
├── data.tf                # Data sources (VPC discovery)
├── locals.tf              # Locals
└── tfvars/
    └── terraform.tfvars   # Valores das variáveis

setup-env.sh               # Deploy automatizado (Terraform)
rollback-setup.sh          # Destrói recursos (Terraform destroy)
```

## Deploy rápido

```bash
# 1. Configure .env
cp .env.example .env
# Edite .env com DB_USER, DB_PASSWORD, AWS_REGION

# 2. Configure tfvars
# Edite infra/tfvars/terraform.tfvars

# 3. Deploy
./setup-env.sh
```

## Destruir recursos

```bash
./rollback-setup.sh
```

## Recursos auxiliares

Cada módulo contém seus próprios recursos de IAM, KMS, CloudWatch e Security Groups,
mantidos de forma organizada e separada por serviço.
