#output "environment_url" {
#  value = module.app_alb.lb_dns_name
#}

output "rds_password" {
  value = data.aws_ssm_parameter.postgres_rds_password.value
  sensitive = true
}
