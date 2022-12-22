// Get current AWS region
data "aws_region" "current" {}

// Get Password from SSM Parameter Store
data "aws_ssm_parameter" "postgres_rds_password" {
  name       = "/${var.environment.name}/postgres"
  depends_on = [aws_ssm_parameter.rds_password]
}