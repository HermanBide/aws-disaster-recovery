
# =============================================================================
# Outputs
# =============================================================================
output "primary_region_azs" {
  value = data.aws_availability_zones.primary.names
}

output "secondary_region_azs" {
  value = data.aws_availability_zones.secondary.names
}

output "primary_ami_id" {
  value = data.aws_ami.amazon_linux_primary.id
}

output "secondary_ami_id" {
  value = data.aws_ami.amazon_linux_secondary.id
}

output "website_url" {
  description = "Main website URL (failover enabled)"
  value       = "https://${var.domain_name}"
}

# VPC Outputs
output "primary_vpc_id" {
  description = "Primary VPC ID"
  value       = aws_vpc.primary.id
}

output "secondary_vpc_id" {
  description = "Secondary VPC ID"
  value       = aws_vpc.secondary.id
}

# ALB Outputs
output "primary_alb_dns" {
  description = "Primary ALB DNS name"
  value       = aws_lb.lb_primary.dns_name
}

output "secondary_alb_dns" {
  description = "Secondary ALB DNS name"
  value       = aws_lb.lb_secondary.dns_name
}

# EC2 Outputs
output "primary_ec2_id" {
  description = "Primary EC2 instance ID (stop this to test failover)"
  value       = aws_instance.ec2_primary.id
}

output "secondary_ec2_id" {
  description = "Secondary EC2 instance ID"
  value       = aws_instance.ec2_secondary.id
}

# Route 53 Outputs
# output "health_check_id" {
#   description = "Route 53 health check ID"
#   value       = aws_route53_health_check.primary.id
# }