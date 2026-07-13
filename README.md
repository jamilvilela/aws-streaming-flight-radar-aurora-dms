# aws-streaming-flight-radar-aurora-dms

**Aurora Serverless v2 PostgreSQL + AWS Batch** — Infraestrutura de banco de dados relacional para dados de voos com schema `flight_radar` e jobs de carga de dados via AWS Batch.

> ⚠️ O serviço **DMS Serverless** foi movido para o repositório separado: [aws-streaming-flight-radar-dms](https://github.com/...)

## Serviços

| Serviço | Descrição |
|---------|-----------|
| **Aurora Serverless v2 PostgreSQL** | Banco relacional com schema `flight_radar` (tabelas: `aircraft`, `airports`, `airlines`, `flights`, `aircraft_positions`) |
| **AWS Batch** | Jobs de carga de dados: `historical`, `stream`, `load-reference` |

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
    └── aws_batch/         # Módulo AWS Batch (carga de dados)

app/
├── seed_data/             # Geradores de dados (historical, stream, load-reference)
├── data/                  # Dados de referência (CSVs)
└── sql/                   # Schema SQL

setup-env.sh               # Deploy automatizado (Terraform)
rollback-setup.sh          # Destrói recursos (Terraform destroy)
```

## Deploy rápido

```bash
# 1. Configure .env
cp .env.example .env
# Edite .env com RDS_ADMIN_PASSWORD, AWS_REGION

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
