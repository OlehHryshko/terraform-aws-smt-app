// Generate Password
resource "random_string" "rds_password" {
  length           = 12
  special          = true
  override_special = "!#$&"

  keepers = {
    kepeer1 = var.db.name_db_administrator
  }
}

// Store Password in SSM Parameter Store
resource "aws_ssm_parameter" "rds_password" {
  name        = "/${var.environment.name}/postgres"
  description = "Master Password for RDS Postgres"
  type        = "SecureString"
  value       = random_string.rds_password.result
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/ecs/smt"
  retention_in_days = 7

  tags = {
    Name       = "smt"
  }
}

// key
resource "tls_private_key" "webserver_private_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}
resource "local_file" "private_key" {
  content = tls_private_key.webserver_private_key.private_key_pem
  filename = "webserver_key.pem"
  file_permission = 0400
}

resource "aws_key_pair" "webserver_key" {
  key_name = "webserver"
  public_key = tls_private_key.webserver_private_key.public_key_openssh
}

// Launch EC2 instance
resource "aws_instance" "webserver" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name  = aws_key_pair.webserver_key.key_name
  security_groups=["${var.environment.name}-smt"]
  tags = {
    Name = "webserver_task1"
  }
  connection {
    type    = "ssh"
    user    = "ec2-user"
    host    = aws_instance.webserver.public_ip
    port    = 22
    private_key = tls_private_key.webserver_private_key.private_key_pem
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
    ]
  }
}

// Create EBS Volume
resource "aws_ebs_volume" "ebs_volume" {
  availability_zone = aws_instance.webserver.availability_zone
  size              = 1
  tags = {
    Name = "webserver-${var.environment.name}-smt"
  }
}

// Attach EBS volume to EC2 instance
resource "aws_volume_attachment" "ebs_attachment" {
  device_name = "/dev/xvdf"
  volume_id   =  aws_ebs_volume.ebs_volume.id
  instance_id = aws_instance.webserver.id
  force_detach = true
  depends_on=[ aws_ebs_volume.ebs_volume,aws_ebs_volume.ebs_volume]
}

//Create S3 Bucket
resource "aws_s3_bucket" "task1_s3bucket" {
  bucket = "website-images-res"
  #acl    = "public-read"
  tags = {
    Name        = "${var.environment.name}-smt-bucket"
    Environment = "${var.environment.name}-smt"
  }
}

// Create CloudFront for S3
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.task1_s3bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.task1_s3bucket.id

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.task1_s3bucket.id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
  }
  price_class = "PriceClass_200"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  depends_on = [aws_s3_bucket.task1_s3bucket]
}

// Deploy Code
resource "null_resource" "nullremote"  {
  depends_on = [  aws_volume_attachment.ebs_attachment,aws_cloudfront_distribution.s3_distribution
  ]
  connection {
    type    = "ssh"
    user    = "ec2-user"
    host    = aws_instance.webserver.public_ip
    port    = 22
    private_key = tls_private_key.webserver_private_key.private_key_pem
  }
  provisioner "remote-exec" {
    inline  = [
      "sudo mkfs.ext4 /dev/xvdf",
      "sudo mount /dev/xvdf /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://git.epam.com/epma-dpaf/streaming-migration-tool/!!!smt!!!.git /var/www/html/",
      "sudo su << EOF",
      "echo \"${aws_cloudfront_distribution.s3_distribution.domain_name}\" >> /var/www/html/path.txt",
      "EOF",
      "sudo systemctl restart httpd"
    ]
  }
}
