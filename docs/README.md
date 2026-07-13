# AWS Streaming Flight Radar — Infraestrutura Aurora + Batch

Infraestrutura do banco **Aurora Serverless v2 PostgreSQL** e jobs de carga de dados via **AWS Batch** para o projeto flight-radar-stream.

> ⚠️ O serviço **DMS Serverless** (replicação Aurora → S3) foi movido para o repositório: [aws-streaming-flight-radar-dms](https://github.com/...)

## Arquitetura

![Arquitetura - aws-streaming-flights](aws-streaming-flights.v0.png)

**Serviços neste repositório:**

1. **Aurora Serverless v2 PostgreSQL**
   - Banco relacional com schema `flight_radar` contendo tabelas dimensionais e de fatos:
     - `aircraft`, `airports`, `airlines` (dimensões)
     - `flights`, `aircraft_positions` (fatos)
   - Replicação lógica habilitada via `pglogical` (compatível com DMS CDC)
   - Escalabilidade automática (0.5 – 8 ACU)

2. **AWS Batch**
   - Jobs de carga de dados históricos e streaming
   - Job definitions: `historical`, `stream`, `load-reference`
   - Compute environment com instâncias Spot para economia

## Principais Componentes

- `infra/`
  - Terraform para provisionar:
    - **Aurora Serverless v2 PostgreSQL** (cluster + writer + leitores opcionais)
    - **AWS Batch** (compute environment, job queues, job definitions)
    - Security Groups (Aurora, Batch)
    - IAM Roles & Policies (Aurora, Batch)
    - KMS Keys
    - CloudWatch Log Groups (Aurora PostgreSQL, Batch)
- `app/seed_data/`
  - Scripts para geração de dados via CLI:
    - `python cli.py historical` — dados históricos
    - `python cli.py stream` — dados de streaming
    - `python cli.py load-reference` — dados de referência (CSVs)

## Como Deployar (resumo)

1. Configurar o arquivo `.env` na raiz do projeto:

   ```bash
   # Editar .env com os valores necessários
   AWS_REGION="us-east-1"
   RDS_ADMIN_PASSWORD="<sua_senha_segura>"
   ```

2. Ajustar `infra/tfvars/terraform.tfvars` com os valores desejados.

3. Configurar credenciais AWS (via `aws configure` ou variáveis de ambiente).

4. Executar o setup + deploy:

   ```bash
   chmod +x setup-env.sh
   ./setup-env.sh
   ```

## Verificação Rápida

```bash
# Cluster Aurora
aws rds describe-db-clusters --db-cluster-identifier flight-radar-stream-aurora

# Batch compute environment
aws batch describe-compute-environments \
  --compute-environments flight-radar-stream-production-batch-env
```

## Conexão com o banco

```bash
# Via psql (valores obtidos do setup-env.sh)
psql -h <aurora_endpoint> -p 5432 -d flightradar -U dbadmin
```

## Geração de dados de teste

Os scripts em `app/seed_data/` geram dados diretamente no banco Aurora:

```bash
# Dados de referência (CSVs → banco)
cd app/seed_data
python cli.py load-reference

# Dados históricos (ex: 12 meses de voos)
python cli.py historical --months 12

# Streaming (simula dados em tempo real)
python cli.py stream --interval 30 --duration 300
```

## Segurança

- Senhas **não** são commitadas (uso de `.env` e `.gitignore`)
- Credenciais armazenadas via variáveis de ambiente
- IAM com princípio de **least privilege**
- Security Groups com acesso restrito ao PostgreSQL (porta 5432)