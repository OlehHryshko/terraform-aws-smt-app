// Generate Password
resource "random_string" "rds_password" {
  length           = 12
  special          = true
  override_special = "!#$&"

  keepers = {
    kepeer1 = var.db.name_db_admininstrator
  }
}

// Store Password in SSM Parameter Store
resource "aws_ssm_parameter" "rds_password" {
  name        = "/${var.environment.name}/postgres"
  description = "Master Password for RDS Postgres"
  type        = "SecureString"
  value       = random_string.rds_password.result
}
