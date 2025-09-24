# Terraform-Projects

## 📌 Overview
This repository contains multiple Terraform projects for provisioning AWS infrastructure.  
Each project is organized into its own directory with clean structure, variables, and helper scripts.

## 📂 Projects

1. **[EC2 Web Project](./terraform-aws-ec2-web)**  
   Provisions an AWS EC2 instance with a simple web server. Creates VPC, subnets, and security groups.

2. **[S3 + RDS Project](./terraform-aws-s3-rds)**  
   Provisions AWS S3 bucket for storage and an RDS instance for relational databases with networking resources.

## 🔧 Common Features
- Modular Terraform code
- Environment management (`dev`, `prod`)  
- `terraform_manage.sh` script to simplify apply/destroy actions
- `.gitignore` for Terraform state files and sensitive data

## 🛠 Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/downloads)  
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with valid credentials  
- An existing AWS key pair  

---
