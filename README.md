# aws-disaster-recovery

# Architecture

```
                  Users
                    |
                Route 53 (DNS failover policy)
                    |
                HTTPS(433)
                    |
        ____________|_______________
       |                            |
us-east-1 (primary)          us-west-2 (secondary)
       |                            |
      VPC                          VPC
       |                            |
    ALB (HTTP:443)             ALB (HTTP:443)
       |                            |
    ACM certification          ACM certification
       |                            |
    EC2 Instance                EC2 Instance

```

# Bullet points
Engineered a fault-tolerant AWS architecture achieving automatic failover between regions with zero manual intervention

A multi-region disaster recovery system on AWS with automated failover using Route 53 health checks
Designed and deployed infrastructure using Terraform, enabling reproducible and scalable environments
Simulated real-world outages and validated RTO/RPO objectives through automated failover testing.


# 📋 Prerequisites:
AWS Account with Route 53 hosted zone
Terraform installed (v1.0+)
AWS CLI configured

# 🛠️ Tech Stack:
Terraform (Infrastructure as Code)
AWS Route 53, ACM, ALB, EC2, VPC

## Resources Created 

**Per Region:**
-1 VPC with 2 public subnets
-1 internet Gateway
-1 Route Table
-1 EC2 Instance (t2.micro)
-1 Application load balancer
-1 Security 

**Route 53:**
-1 Health Check
-2 Failover records (Primary + Secondary)
