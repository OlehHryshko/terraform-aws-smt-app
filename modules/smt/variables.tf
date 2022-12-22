variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t3.nano"
}

variable "ami_filter" {
  description = "Name filter and owner for AMI"

  type    = object ({
    name  = string
    owner = string
  })

  default = {
    name  = "bitnami-tomcat-*-x86_64-hvm-ebs-nami"
    owner = "979382823631" # Bitnami
  }
}

variable "environment" {
  description = "Deployment environment"

  type        = object ({
    name           = string
    network_prefix = string
  })
  default = {
    name           = "dev"
    network_prefix = "10.0"
  }
}

variable "asg_min" {
  description = "Minimum instance count for the ASG"
  default     = 1
}

variable "asg_max" {
  description = "Maximum instance count for the ASG"
  default     = 2
}

variable "db" {
  description = "postgres"

  type = object({
    name_db_administrator  = string
    storage_type           = string
    instance_class         = string
    engine                 = string
    engine_version         = string
    allocated_storage      = number
    port                   = number
  })

  default = {
    name_db_administrator   = "administrator"
    storage_type             = "gp2"
    instance_class           = "db.t3.micro"
    engine                   = "postgres"
    engine_version           = "14"
    allocated_storage        = 5
    port                    = 5432
  }
}

