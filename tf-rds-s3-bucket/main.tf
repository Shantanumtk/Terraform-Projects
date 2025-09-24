# -----------------------------
# S3 Bucket
# -----------------------------
resource "aws_s3_bucket" "web_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = var.s3_bucket_name
    Environment = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "web_bucket_versioning" {
  bucket = aws_s3_bucket.web_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------
# VPC for RDS
# -----------------------------
resource "aws_vpc" "rds_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "rds-vpc"
  }
}

# -----------------------------
# Fetch AZs
# -----------------------------
data "aws_availability_zones" "available" {}

# Subnet 1
resource "aws_subnet" "rds_subnet_1" {
  vpc_id                  = aws_vpc.rds_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "rds-subnet-1"
  }
}

# Subnet 2
resource "aws_subnet" "rds_subnet_2" {
  vpc_id                  = aws_vpc.rds_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "rds-subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "rds_igw" {
  vpc_id = aws_vpc.rds_vpc.id

  tags = {
    Name = "rds-igw"
  }
}

# Route Table
resource "aws_route_table" "rds_public_rt" {
  vpc_id = aws_vpc.rds_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rds_igw.id
  }

  tags = {
    Name = "rds-public-rt"
  }
}

# Associate Subnets to Route Table
resource "aws_route_table_association" "rds_subnet_1_assoc" {
  subnet_id      = aws_subnet.rds_subnet_1.id
  route_table_id = aws_route_table.rds_public_rt.id
}

resource "aws_route_table_association" "rds_subnet_2_assoc" {
  subnet_id      = aws_subnet.rds_subnet_2.id
  route_table_id = aws_route_table.rds_public_rt.id
}

# -----------------------------
# Security Group for RDS
# -----------------------------
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow MySQL access from anywhere"
  vpc_id      = aws_vpc.rds_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # restrict in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# -----------------------------
# RDS Subnet Group
# -----------------------------
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.rds_subnet_1.id,
    aws_subnet.rds_subnet_2.id
  ]

  tags = {
    Name = "rds-subnet-group"
  }
}

# -----------------------------
# RDS Instance
# -----------------------------
resource "aws_db_instance" "rds_instance" {
  allocated_storage      = var.db_allocated_storage
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = true

  tags = {
    Name = "terraform-rds-instance"
  }
}
