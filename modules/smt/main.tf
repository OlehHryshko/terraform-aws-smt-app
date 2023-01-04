module "app_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["${data.aws_region.current.name}a", "${data.aws_region.current.name}b", "${data.aws_region.current.name}c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}


module "app_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.16.2"

  vpc_id  = module.app_vpc.vpc_id
  name    = "${var.environment.name}-smt"
  ingress_rules = ["https-443-tcp", "http-80-tcp", "postgresql-tcp", "ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}


module "rds_db_instance" {
  source  = "terraform-aws-modules/rds/aws"
  version = "5.2.2"

  family               = "${var.db.engine}${var.db.engine_version}"
  identifier           = "${var.environment.name}-smt"
  allocated_storage    = var.db.allocated_storage
  storage_type         = var.db.storage_type
  engine               = var.db.engine
  port                 = var.db.port
  engine_version       = var.db.engine_version
  instance_class       = var.db.instance_class
  username             = var.db.name_db_administrator
  password             = data.aws_ssm_parameter.postgres_rds_password.value
  skip_final_snapshot  = true
  apply_immediately    = true
}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "${var.environment.name}-smt"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        # You can set a simple string and ECS will create the CloudWatch log group for you
        # or you can create the resource yourself as shown here to better manage retetion, tagging, etc.
        # Embedding it into the module is not trivial and therefore it is externalized
        cloud_watch_log_group_name = aws_cloudwatch_log_group.this.name
      }
    }
  }

  # Capacity provider
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
        base   = 20
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  tags = {
    Name       = "${var.environment.name}-smt"
    Environment = var.environment.name
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
#module "app_autoscaling" {
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



