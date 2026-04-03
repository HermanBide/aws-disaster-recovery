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
    #   project     = "phoenix"
    #   environment = "production"
      managedby   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-east-1"

  default_tags {
    tags = {
    #   project     = "Disaster-recovery"
    #   environment = "production"
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

# resource "aws_vpc" "secondary" {
#   provider = aws.secondary
#   cidr_block           = "10.1.0.0/16"
#   enable_dns_hostnames = true
#   enable_dns_support   = true

#     tags = {
#     Name = "${var.project_name}-secondary-vpc"
#   }
# }

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