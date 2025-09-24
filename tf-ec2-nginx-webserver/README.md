# Terraform AWS EC2 NGINX Web Server Project

## 📌 Overview

This project provisions an AWS EC2 instance using Terraform and deploys a simple web server. It creates the necessary networking resources (VPC, subnets, security group) and installs Apache/Nginx on the instance using a startup script.

## 📂 Directory Structure

```
terraform-aws-ec2-web/
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
   cd terraform-aws-ec2-web
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

6. Get the EC2 public IP from Terraform outputs and open it in your browser to see the web server.

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy -auto-approve
```

---

## 🔧 Using the Helper Script

This project includes a helper script `terraform_manage.sh` to simplify applying and destroying infrastructure.

#Screenshot of Project
<img width="1694" height="921" alt="Lab-3-Terraform-EC2-Nginx-WebServer" src="https://github.com/user-attachments/assets/a68180bb-b0f2-4638-9716-37bdab9c686e" />

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
