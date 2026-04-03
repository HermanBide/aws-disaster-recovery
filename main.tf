# =================================================================================================================================
# AWS Route 53 Failover with HTTPS
# ===============================================================================================================
# Multi-region disaster recovery setup with automatic failover
# Primary: us-east-1 | Secondary us-west-2
# ===============================================================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.0"
}

# ==============================================================================================================
# Providers - multi-Region setup
# ==============================================================================================================
provider "aws" {
  alias  = "primary"
  region = "us-west-1"

  default_tags {
    tags = {
      project     = "disaster-recovery"
      environment = "production"
      managedby   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-east-1"

  default_tags {
    tags = {
      project     = "Disaster-recovery"
      environment = "production"
      managedby   = "terraform"
    }
  }
}

# ========================================================================================================
# Data Source
# ========================================================================================================

# Get availability zones - primary region
data "aws_availability_zones" "primary" {
    provider = aws.primary
    state = "available"

}

# Get availability zones - secondary region
data "aws_availability_zones" "secondary" {
    provider = aws.secondary
    state = "available"
}

# Get latest Amazon Linux 2023 AMI - Primary Region
data "aws_ami" "amazon_linux_primary" {
  provider    = aws.primary
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    #amazon linux 2023 - amazon machine image
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    #hardware virtual machine
    values = ["hvm"]
  }
}

# Get latest Amazon Linux 2023 AMI - Secondary Region
data "aws_ami" "amazon_linux_secondary" {
  provider    = aws.secondary
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# route 53 to direct traffic
resource "aws_route53_zone" "main" {
  provider = aws.primary
  name = var.domain_name
}

# ==============================================================================================================
# VPC - PRIMARY REGION (us-west-1)
# ==================================================================================================================

resource "aws_vpc" "primary" {
  provider = aws.primary
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

    tags = {
    Name = "${var.project_name}-primary-vpc"
  }
}


# IGW
resource "aws_internet_gateway" "igw_primary" {
  provider = aws.primary
  vpc_id = aws_vpc.primary.id

  tags = {
    name = "${var.project_name}-primary-igw"
  }
}

# Primary Subnet
resource "aws_subnet" "primary_public_1" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.primary.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-primary-public-1"
  }
}

resource "aws_subnet" "primary_public_2" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.primary.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-primary-public-2"
  }
}
#creates a virtual routing table for your VPC
resource "aws_route_table" "primary_public" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_primary.id
  }

  tags = {
    Name = "${var.project_name}-primary-public-rt"
  }
}

#High Availability zones 1 & 2 incase one availability zone crashes.
resource "aws_route_table_association" "primary_public_1" {
  provider       = aws.primary
  subnet_id      = aws_subnet.primary_public_1.id
  route_table_id = aws_route_table.primary_public.id
}

resource "aws_route_table_association" "primary_public_2" {
  provider       = aws.primary
  subnet_id      = aws_subnet.primary_public_2.id
  route_table_id = aws_route_table.primary_public.id
}

# =============================================================================
# VPC - SECONDARY REGION (us-east-1)
# =============================================================================

resource "aws_vpc" "secondary" {
  provider             = aws.secondary
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-secondary-vpc"
  }
}

resource "aws_internet_gateway" "igw_secondary" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  tags = {
    Name = "${var.project_name}-secondary-igw"
  }
}

resource "aws_subnet" "secondary_public_1" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = data.aws_availability_zones.secondary.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-secondary-public-1"
  }
}

resource "aws_subnet" "secondary_public_2" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = data.aws_availability_zones.secondary.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-secondary-public-2"
  }
}

resource "aws_route_table" "secondary_public" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_secondary.id
  }

  tags = {
    Name = "${var.project_name}-secondary-public-rt"
  }
}

resource "aws_route_table_association" "secondary_public_1" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_public_1.id
  route_table_id = aws_route_table.secondary_public.id
}

resource "aws_route_table_association" "secondary_public_2" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_public_2.id
  route_table_id = aws_route_table.secondary_public.id
}

# =============================================================================
# ACM Certificates
# =============================================================================

# ACM Certificate - Primary Region (us-west-1)
resource "aws_acm_certificate" "acm_primary" {
  provider          = aws.primary
  domain_name       = var.domain_name
  validation_method = "DNS"

#create new cert before replacing old cert.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name   = "${var.project_name}-primary-cert"
    Region = "us-west-1"
  }
}

# ACM Certificate - Secondary Region (us-east-1)
resource "aws_acm_certificate" "acm_secondary" {
  provider          = aws.secondary
  domain_name       = var.domain_name
  validation_method = "DNS"

#create new cert before replacing old cert.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name   = "${var.project_name}-secondary-cert"
    Region = "us-east-1"
  }
}

#DNS Validation Record
# DNS Validation Record (only need one since same domain)
resource "aws_route53_record" "cert_validation" {
  provider = aws.primary

  for_each = {
    for dvo in aws_acm_certificate.acm_primary.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Certificate Validation - Primary
resource "aws_acm_certificate_validation" "acm_validate_primary" {
  provider                = aws.primary
  certificate_arn         = aws_acm_certificate.acm_primary.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Certificate Validation - Secondary
resource "aws_acm_certificate_validation" "acm_validate_secondary" {
  provider                = aws.secondary
  certificate_arn         = aws_acm_certificate.acm_secondary.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# =============================================================================
# PRIMARY REGION - Security Groups, EC2, ALB
# =============================================================================

# Security Group - ALB (Primary)
resource "aws_security_group" "alb_primary" {
  provider    = aws.primary
  name        = "${var.project_name}-primary-alb-sg"
  description = "Security group for Primary ALB"
  vpc_id      = aws_vpc.primary.id

    ingress {
    description = "HTTP"
    from_port   = 80 #Allows standard, unencrypted web traffic.
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443 # Allows secure, encrypted web traffic.
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-primary-alb-sg"
  }
}

# Security Group - EC2 (Primary)
resource "aws_security_group" "sg_ec2_primary" {
  provider    = aws.primary
  name        = "${var.project_name}-primary-ec2-sg"
  description = "Security group for Primary EC2"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_primary.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-primary-ec2-sg"
  }
}

# EC2 Instance - Primary
resource "aws_instance" "ec2_primary" {
  provider               = aws.primary
  ami                    = data.aws_ami.amazon_linux_primary.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.primary_public_1.id
  vpc_security_group_ids = [aws_security_group.sg_ec2_primary.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    region      = "us-west-1"
    region_name = "N. California"
    role        = "PRIMARY"
    role_color  = "#1a5f2a"
    badge_color = "#FFD700"
    text_color  = "#90EE90"
  }))

  tags = {
    Name = "${var.project_name}-primary-web"
  }
}

# Application Load Balancer - Primary
resource "aws_lb" "primary" {
  provider           = aws.primary
  name               = "${var.project_name}-primary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_primary.id]
  subnets            = [aws_subnet.primary_public_1.id, aws_subnet.primary_public_2.id]

  tags = {
    Name = "${var.project_name}-primary-alb"
  }
}

# Target Group - Primary
resource "aws_lb_target_group" "primary" {
  provider = aws.primary
  name     = "${var.project_name}-primary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.primary.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-primary-tg"
  }
}

# Target Group Attachment - Primary
resource "aws_lb_target_group_attachment" "primary" {
  provider         = aws.primary
  target_group_arn = aws_lb_target_group.primary.arn
  target_id        = aws_instance.primary.id
  port             = 80
}

# ALB Listener - HTTPS (Primary)
resource "aws_lb_listener" "primary_https" {
  provider          = aws.primary
  load_balancer_arn = aws_lb.primary.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.primary.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary.arn
  }
}

# ALB Listener - HTTP Redirect (Primary)
resource "aws_lb_listener" "primary_http" {
  provider          = aws.primary
  load_balancer_arn = aws_lb.primary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}