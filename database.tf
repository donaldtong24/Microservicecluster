# RDS Postgres backing store for the app's /visits endpoint (main.py).
# Uses the kubernetes provider already configured in monitoring.tf.

resource "aws_db_subnet_group" "postgres" {
  name       = "microservice-postgres"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Project = "MicroserviceCluster"
  }
}

# Only the EKS worker nodes can reach Postgres — nothing public, nothing
# else in the VPC.
resource "aws_security_group" "rds" {
  name_prefix = "microservice-postgres-"
  description = "Allow Postgres access from EKS worker nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Postgres from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "MicroserviceCluster"
  }
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_instance" "postgres" {
  identifier = "microservice-postgres"
  engine     = "postgres"
  # Major-version-only: RDS resolves the latest supported minor at create
  # time and auto_minor_version_upgrade (default true) keeps it patched,
  # instead of a pinned minor version going stale in this file over time.
  engine_version = "16"

  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "microservice"
  username = "appuser"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false # single-AZ for this demo; see README for the Multi-AZ note

  # Learning/demo project — torn down and recreated often. Not the right
  # defaults for a real production database.
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
  backup_retention_period = 1

  tags = {
    Project = "MicroserviceCluster"
  }
}

# Consumed by charts/python-microservice via env.DATABASE_URL (secretKeyRef)
# in values-prod.yaml. Namespace must match the Helm release's namespace —
# "default" here because none of the README's helm install commands pass -n.
resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "python-microservice-db"
    namespace = "default"
  }

  data = {
    DATABASE_URL = "postgresql://${aws_db_instance.postgres.username}:${random_password.db.result}@${aws_db_instance.postgres.address}:5432/${aws_db_instance.postgres.db_name}"
  }

  type = "Opaque"
}

output "database_url" {
  value     = "postgresql://${aws_db_instance.postgres.username}:${random_password.db.result}@${aws_db_instance.postgres.address}:5432/${aws_db_instance.postgres.db_name}"
  sensitive = true
}
