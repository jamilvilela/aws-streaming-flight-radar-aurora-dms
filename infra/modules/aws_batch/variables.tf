# Variables for AWS Batch Module

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, production)"
  type        = string
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
}

variable "tags" {
  description = "Tags comuns"
  type        = map(string)
  default     = {}
}

variable "subnet_ids" {
  description = "IDs das subnets privadas para o compute environment"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group ID para as instâncias do Batch"
  type        = string
}

variable "ecr_image_uri" {
  description = "URI da imagem Docker no ECR (ex: 123456789.dkr.ecr.us-east-1.amazonaws.com/flight-radar:latest)"
  type        = string
}

variable "db_host" {
  description = "Endpoint do Aurora PostgreSQL"
  type        = string
}

variable "db_port" {
  description = "Porta do banco"
  type        = string
  default     = "5432"
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "flightradar"
}

variable "db_user" {
  description = "Usuário do banco"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Senha do banco (sensitive)"
  type        = string
  sensitive   = true
}

variable "efs_file_system_id" {
  description = "ID do EFS File System para armazenamento compartilhado"
  type        = string
}

variable "efs_file_system_arn" {
  description = "ARN do EFS File System"
  type        = string
}

# Compute Environment Config
variable "compute_instance_types" {
  description = "Tipos de instância EC2 para o compute environment"
  type        = list(string)
  default     = ["m6i.large", "m6i.xlarge", "m6i.2xlarge", "r6i.large", "r6i.xlarge"]
}

variable "compute_min_vcpus" {
  description = "Mínimo de vCPUs no compute environment"
  type        = number
  default     = 0
}

variable "compute_max_vcpus" {
  description = "Máximo de vCPUs no compute environment"
  type        = number
  default     = 256
}

variable "compute_desired_vcpus" {
  description = "vCPUs desejados iniciais"
  type        = number
  default     = 0
}

variable "compute_spot_bid_percentage" {
  description = "Porcentagem do preço on-demand para spot instances (0-100)"
  type        = number
  default     = 70
}

# Job Definition Resources
variable "job_historical_vcpus" {
  description = "vCPUs para job historical"
  type        = number
  default     = 4
}

variable "job_historical_memory" {
  description = "Memória (MiB) para job historical"
  type        = number
  default     = 16384
}

variable "job_stream_vcpus" {
  description = "vCPUs para job stream"
  type        = number
  default     = 2
}

variable "job_stream_memory" {
  description = "Memória (MiB) para job stream"
  type        = number
  default     = 8192
}

variable "job_load_ref_vcpus" {
  description = "vCPUs para job load-reference"
  type        = number
  default     = 2
}

variable "job_load_ref_memory" {
  description = "Memória (MiB) para job load-reference"
  type        = number
  default     = 8192
}

variable "log_retention_days" {
  description = "Retenção de logs em dias"
  type        = number
  default     = 30
}