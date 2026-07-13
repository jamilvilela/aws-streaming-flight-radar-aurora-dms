# AWS Batch para execução de jobs de carga de dados (historical, stream, etc.)
# Permite rodar scripts Python em containers com recursos escaláveis

# -------------------------------------------------------------------------------
# Compute Environment (Ambiente de computação gerenciado)
# -------------------------------------------------------------------------------
resource "aws_batch_compute_environment" "this" {
  name       = "${var.project_name}-${var.environment}-batch-env"
  type       = "MANAGED"
  state      = "ENABLED"
  service_role = aws_iam_role.batch_service_role.arn

  compute_resources {
    type                = "EC2"
    instance_role       = aws_iam_instance_profile.batch_instance_profile.arn
    instance_type       = toset(var.compute_instance_types)
    min_vcpus           = var.compute_min_vcpus
    max_vcpus           = var.compute_max_vcpus
    desired_vcpus       = var.compute_desired_vcpus
    subnets             = var.subnet_ids
    security_group_ids  = [var.security_group_id]
    allocation_strategy = "BEST_FIT_PROGRESSIVE"
    bid_percentage      = var.compute_spot_bid_percentage
    spot_iam_fleet_role = var.compute_spot_bid_percentage > 0 ? aws_iam_role.batch_spot_fleet_role.arn : null
    tags                = merge(var.tags, { Name = "${var.project_name}-${var.environment}-batch-compute" })
  }
}

# -------------------------------------------------------------------------------
# Job Queue (Fila de jobs)
# -------------------------------------------------------------------------------
resource "aws_batch_job_queue" "this" {
  name                 = "${var.project_name}-${var.environment}-job-queue"
  state                = "ENABLED"
  priority             = 1
  compute_environment_order {
    order = 1
    compute_environment = aws_batch_compute_environment.this.arn
  }
  tags                 = var.tags
}

# -------------------------------------------------------------------------------
# Job Definition - Historical Generator (Carga histórica)
# -------------------------------------------------------------------------------
resource "aws_batch_job_definition" "historical" {
  name                  = "${var.project_name}-${var.environment}-historical"
  type                  = "container"
  platform_capabilities = ["EC2"]
  container_properties = jsonencode({
    image            = var.ecr_image_uri
    vcpus            = var.job_historical_vcpus
    memory           = var.job_historical_memory
    command          = ["python", "app/seed_data/cli.py", "historical"]
    jobRoleArn       = aws_iam_role.batch_job_role.arn
    executionRoleArn = aws_iam_role.batch_execution_role.arn
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = var.db_port },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_user },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "AWS_DEFAULT_REGION", value = var.aws_region },
      { name = "PYTHONUNBUFFERED", value = "1" }
    ]
    mountPoints = var.efs_file_system_id != "" ? [
      { sourceVolume = "efs", containerPath = "/efs", readOnly = false }
    ] : []
    volumes = var.efs_file_system_id != "" ? [
      { name = "efs", efsVolumeConfiguration = { fileSystemId = var.efs_file_system_id, rootDirectory = "/batch", transitEncryption = "ENABLED" } }
    ] : []
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "historical"
      }
    }
  })
  tags = var.tags
}

# -------------------------------------------------------------------------------
# Job Definition - Stream Generator (CDC streaming)
# -------------------------------------------------------------------------------
resource "aws_batch_job_definition" "stream" {
  name                  = "${var.project_name}-${var.environment}-stream"
  type                  = "container"
  platform_capabilities = ["EC2"]
  container_properties = jsonencode({
    image            = var.ecr_image_uri
    vcpus            = var.job_stream_vcpus
    memory           = var.job_stream_memory
    command          = ["python", "app/seed_data/cli.py", "stream"]
    jobRoleArn       = aws_iam_role.batch_job_role.arn
    executionRoleArn = aws_iam_role.batch_execution_role.arn
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = var.db_port },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_user },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "AWS_DEFAULT_REGION", value = var.aws_region },
      { name = "PYTHONUNBUFFERED", value = "1" }
    ]
    mountPoints = var.efs_file_system_id != "" ? [
      { sourceVolume = "efs", containerPath = "/efs", readOnly = false }
    ] : []
    volumes = var.efs_file_system_id != "" ? [
      { name = "efs", efsVolumeConfiguration = { fileSystemId = var.efs_file_system_id, rootDirectory = "/batch", transitEncryption = "ENABLED" } }
    ] : []
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "stream"
      }
    }
  })
  tags = var.tags
}

# -------------------------------------------------------------------------------
# Job Definition - Load Reference (Dados de referência)
# -------------------------------------------------------------------------------
resource "aws_batch_job_definition" "load_reference" {
  name                  = "${var.project_name}-${var.environment}-load-reference"
  type                  = "container"
  platform_capabilities = ["EC2"]
  container_properties = jsonencode({
    image            = var.ecr_image_uri
    vcpus            = var.job_load_ref_vcpus
    memory           = var.job_load_ref_memory
    command          = ["python", "app/seed_data/cli.py", "load-reference"]
    jobRoleArn       = aws_iam_role.batch_job_role.arn
    executionRoleArn = aws_iam_role.batch_execution_role.arn
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = var.db_port },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_user },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "AWS_DEFAULT_REGION", value = var.aws_region },
      { name = "PYTHONUNBUFFERED", value = "1" }
    ]
    mountPoints = var.efs_file_system_id != "" ? [
      { sourceVolume = "efs", containerPath = "/efs", readOnly = false }
    ] : []
    volumes = var.efs_file_system_id != "" ? [
      { name = "efs", efsVolumeConfiguration = { fileSystemId = var.efs_file_system_id, rootDirectory = "/batch", transitEncryption = "ENABLED" } }
    ] : []
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "load-reference"
      }
    }
  })
  tags = var.tags
}

# -------------------------------------------------------------------------------
# IAM Roles
# -------------------------------------------------------------------------------

# Service Role para Batch
resource "aws_iam_role" "batch_service_role" {
  name = "${var.project_name}-${var.environment}-batch-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "batch.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "batch_service_role_policy" {
  role       = aws_iam_role.batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# Spot Fleet Role
resource "aws_iam_role" "batch_spot_fleet_role" {
  name = "${var.project_name}-${var.environment}-batch-spot-fleet-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "spotfleet.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "batch_spot_fleet_role_policy" {
  role       = aws_iam_role.batch_spot_fleet_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

# Instance Profile para EC2
resource "aws_iam_role" "batch_instance_role" {
  name = "${var.project_name}-${var.environment}-batch-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_instance_profile" "batch_instance_profile" {
  name = "${var.project_name}-${var.environment}-batch-instance-profile"
  role = aws_iam_role.batch_instance_role.name
}

resource "aws_iam_role_policy_attachment" "batch_instance_ecs" {
  role       = aws_iam_role.batch_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "batch_instance_efs" {
  role       = aws_iam_role.batch_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
}

resource "aws_iam_role_policy_attachment" "batch_instance_logs" {
  role       = aws_iam_role.batch_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "batch_instance_secrets" {
  role       = aws_iam_role.batch_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# Job Role (permissões do job em execução)
resource "aws_iam_role" "batch_job_role" {
  name = "${var.project_name}-${var.environment}-batch-job-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "batch_job_policy" {
  name = "${var.project_name}-${var.environment}-batch-job-policy"
  role = aws_iam_role.batch_job_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.batch_logs.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = var.efs_file_system_arn
      },
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = "*"
      }
    ]
  })
}

# Execution Role (para pull da imagem ECR)
resource "aws_iam_role" "batch_execution_role" {
  name = "${var.project_name}-${var.environment}-batch-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "batch_execution_role_policy" {
  role       = aws_iam_role.batch_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -------------------------------------------------------------------------------
# CloudWatch Log Group
# -------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "batch_logs" {
  name              = "/aws/batch/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# -------------------------------------------------------------------------------
# EFS Access Point (opcional, para isolamento)
# -------------------------------------------------------------------------------
resource "aws_efs_access_point" "batch" {
  file_system_id = var.efs_file_system_id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/batch"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0755"
    }
  }
  tags = var.tags
}