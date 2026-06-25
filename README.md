# aws-streaming-flight-radar-aurora-dms

**Aurora Serverless v2 PostgreSQL + AWS DMS Serverless** — Pipeline de replicação de dados de voos do Aurora PostgreSQL para S3 (Parquet) via DMS com captura CDC.

## Serviços

| Serviço | Descrição |
|---------|-----------|
| **Aurora Serverless v2 PostgreSQL** | Banco relacional com schema `flight_radar` (tabelas: `aircraft`, `airports`, `airlines`, `flights`, `aircraft_positions`) |
| **AWS DMS Serverless** | Replicação Full Load + CDC do Aurora para S3 no formato Parquet |

## Estrutura

```
infra/                     # Terraform
├── main.tf                # Orquestração dos módulos
├── variables.tf           # Variáveis de entrada
├── outputs.tf             # Outputs do stack
├── providers.tf           # Provider AWS
├── data.tf                # Data sources
├── locals.tf              # Locals
├── tfvars/
│   └── terraform.tfvars   # Valores das variáveis
└── modules/
    ├── aurora_postgres/   # Módulo Aurora Serverless v2
    └── dms_serverless/    # Módulo DMS Serverless (Aurora → S3)

app/seed_data/
└── generate_dms_data.py   # Geração de dados de teste

setup-env.sh               # Deploy automatizado (Terraform)
rollback-setup.sh          # Destrói recursos (Terraform destroy)
```

## Deploy rápido

```bash
# 1. Configure .env
cp .env.example .env
# Edite .env com RDS_ADMIN_PASSWORD, AWS_REGION

# 2. Configure tfvars
# Edite infra/tfvars/terraform.tfvars com VPC, subnets

# 3. Deploy
./setup-env.sh

# 4. Gere dados de teste
cd app/seed_data
pip install -r ../requirements.txt
python generate_dms_data.py all
```

## Destruir recursos

```bash
./rollback-setup.sh
```
