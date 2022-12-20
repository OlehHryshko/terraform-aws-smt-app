provider "aws" {
  profile   = "default"
}

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

// Get Password from SSM Parameter Store
data "aws_ssm_parameter" "postgres_rds_password" {
  name       = "/${var.environment.name}/postgres"
  depends_on = [aws_ssm_parameter.rds_password]
}

module "app_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a","us-west-2b","us-west-2c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}

module "app_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.13.0"

  vpc_id  = module.app_vpc.vpc_id
  name    = "${var.environment.name}-smt"
  ingress_rules = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

module "rds_db_instance" {
  source  = "terraform-aws-modules/rds/aws//modules/db_instance"
  version = "5.2.1"

  identifier           = "${var.environment.name}-smt"
  allocated_storage    = var.db.allocated_storage
  storage_type         = var.db.storage_type
  engine               = var.db.engine
  port                 = var.db.port
  engine_version       = var.db.engine_version
  instance_class       = var.db.instance_class
  username             = var.db.name_db_admininstrator
  password             = data.aws_ssm_parameter.postgres_rds_password.value
  skip_final_snapshot  = true
  apply_immediately    = true
}

module "delegation_sets" {
  source  = "terraform-aws-modules/route53/aws//modules/delegation-sets"
  version = "~> 2.0"

  delegation_sets = {
    "smt" = {
      reference_name = "smt"
    }
  }
}

module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "smt1.com" = {
      comment           = "smt1.com"
      delegation_set_id = module.delegation_sets.route53_delegation_set_id["smt"]
    }

    "smt2.com" = {
      comment           = "smt2.com"
      delegation_set_id = module.delegation_sets.route53_delegation_set_id["smt"]
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }

  depends_on = [module.delegation_sets]
}

module "resolver_rule_associations" {
  source  = "terraform-aws-modules/route53/aws//modules/resolver-rule-associations"
  version = "~> 2.0"

  vpc_id = "vpc-185a3e2f2d6d2c863"

  resolver_rule_associations = {
    foo = {
      resolver_rule_id = "rslvr-rr-2d3e8e42eea14f20a"
    },
    bar = {
      name             = "bar"
      resolver_rule_id = "rslvr-rr-2d3e8e42eea14f20a"
      vpc_id           = "vpc-285a3e2f2d6d2c863"
    },
  }
}

#data "aws_ami" "app_ami" {
#  most_recent = true
#
#  filter {
#    name   = "name"
#    values = [var.ami_filter.name]
#  }
#
#  filter {
#    name   = "virtualization-type"
#    values = ["hvm"]
#  }
#
#  owners = [var.ami_filter.owner]
#}
#
#module "blog_autoscaling" {
#  source  = "terraform-aws-modules/autoscaling/aws"
#  version = "6.5.2"
#
#  name = "${var.environment.name}-smt"
#
#  min_size            = var.asg_min
#  max_size            = var.asg_max
#  vpc_zone_identifier = module.app_vpc.public_subnets
#  target_group_arns   = module.app_alb.target_group_arns
#  security_groups     = [module.app_sg.security_group_id]
#  instance_type       = var.instance_type
#  image_id            = data.aws_ami.app_ami.id
#}
#
#module "app_alb" {
#  source  = "terraform-aws-modules/alb/aws"
#  version = "~> 6.0"
#
#  name = "${var.environment.name}-smt-alb"
#
#  load_balancer_type = "application"
#
#  vpc_id             = module.app_vpc.vpc_id
#  subnets            = module.app_vpc.public_subnets
#  security_groups    = [module.app_sg.security_group_id]
#
#  target_groups = [
#    {
#      name_prefix      = "${var.environment.name}-"
#      backend_protocol = "HTTP"
#      backend_port     = 80
#      target_type      = "instance"
#    }
#  ]
#
#  http_tcp_listeners = [
#    {
#      port               = 80
#      protocol           = "HTTP"
#      target_group_index = 0
#    }
#  ]
#
#  tags = {
#    Environment = var.environment.name
#  }
#}



