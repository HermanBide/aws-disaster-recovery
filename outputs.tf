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