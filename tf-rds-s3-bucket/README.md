# Terraform AWS S3 + RDS Project

## 📌 Overview

This project provisions **AWS S3** (for storage) and an **AWS RDS instance** (for relational database) using Terraform. It also creates the required networking resources (VPC, subnets, security group, and DB subnet group).

## 📂 Directory Structure

```
terraform-aws-s3-rds/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── provider.tf
├── terraform_manage.sh
└── .gitignore
```

## 🚀 Steps to Deploy

1. Navigate to the project folder:

   ```bash
   cd terraform-aws-s3-rds
   ```

2. Initialize Terraform:

   ```bash
   terraform init
   ```

3. Validate configuration:

   ```bash
   terraform validate
   ```

4. Plan the infrastructure:

   ```bash
   terraform plan
   ```

5. Apply the configuration:

   ```bash
   terraform apply -auto-approve
   ```

6. Once complete, Terraform will output the S3 bucket name and the RDS endpoint.

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy -auto-approve
```

---

## 🔧 Using the Helper Script

This project includes a helper script `terraform_manage.sh` to simplify applying and destroying infrastructure.

## Screenshot of the Project
<img width="1694" height="921" alt="Lab-3-Terraform-RDS-S3-Bucket" src="https://github.com/user-attachments/assets/d732e809-e175-41f0-914d-3f67f2e1fdf9" />

### Usage

```bash
# -------------------------
# Usage
# ./terraform_manage.sh [workspace] [action]
#
# Examples:
#   ./terraform_manage.sh                # defaults to dev apply
#   ./terraform_manage.sh dev apply      # apply infra in dev
#   ./terraform_manage.sh prod apply     # apply infra in prod
#   ./terraform_manage.sh dev destroy    # destroy infra in dev
#   ./terraform_manage.sh prod destroy   # destroy infra in prod
# -------------------------
```
