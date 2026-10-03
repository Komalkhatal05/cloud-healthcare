terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# =========================================================
# AWS PROVIDER
# =========================================================

provider "aws" {
  region = "ap-south-1"
}

# =========================================================
# RANDOM PASSWORD
# RDS password automatically generated
# =========================================================

resource "random_password" "rds_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*"
}

# =========================================================
# RANDOM S3 BUCKET SUFFIX
# S3 bucket name must be globally unique
# =========================================================

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# =========================================================
# VPC
# =========================================================

resource "aws_vpc" "healthcare_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "healthcare-vpc"
    Project     = "Healthcare-Cloud-System"
    Environment = "Development"
  }
}

# =========================================================
# INTERNET GATEWAY
# =========================================================

resource "aws_internet_gateway" "healthcare_igw" {
  vpc_id = aws_vpc.healthcare_vpc.id

  tags = {
    Name = "healthcare-internet-gateway"
  }
}

# =========================================================
# PUBLIC SUBNET
# =========================================================

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.healthcare_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "healthcare-public-subnet"
  }
}

# =========================================================
# PRIVATE SUBNET 1
# =========================================================

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.healthcare_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "healthcare-private-subnet-1"
  }
}

# =========================================================
# PRIVATE SUBNET 2
# =========================================================

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.healthcare_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "healthcare-private-subnet-2"
  }
}

# =========================================================
# PUBLIC ROUTE TABLE
# =========================================================

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.healthcare_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.healthcare_igw.id
  }

  tags = {
    Name = "healthcare-public-route-table"
  }
}

# =========================================================
# PUBLIC ROUTE TABLE ASSOCIATION
# =========================================================

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# =========================================================
# EC2 SECURITY GROUP
# =========================================================

resource "aws_security_group" "web_sg" {
  name        = "healthcare-web-sg"
  description = "Security group for healthcare web server"
  vpc_id      = aws_vpc.healthcare_vpc.id

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH - restrict this later to your IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "healthcare-web-security-group"
  }
}

# =========================================================
# AMAZON LINUX AMI
# Automatically finds current Amazon Linux 2023 AMI
# =========================================================

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# =========================================================
# EC2 WEB SERVER
# =========================================================

resource "aws_instance" "healthcare_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  tags = {
    Name    = "healthcare-web-server"
    Project = "Healthcare-Cloud-System"
  }
}

# =========================================================
# S3 BUCKET
# Bucket name automatically becomes unique
# =========================================================

resource "aws_s3_bucket" "healthcare_storage" {
  bucket = "healthcare-cloud-system-${random_id.bucket_suffix.hex}"

  tags = {
    Name    = "healthcare-storage"
    Project = "Healthcare-Cloud-System"
  }
}

# =========================================================
# S3 VERSIONING
# =========================================================

resource "aws_s3_bucket_versioning" "healthcare_storage_versioning" {
  bucket = aws_s3_bucket.healthcare_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# =========================================================
# DYNAMODB TABLE
# =========================================================

resource "aws_dynamodb_table" "patient_records" {
  name         = "healthcare-patient-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "patient_id"

  attribute {
    name = "patient_id"
    type = "S"
  }

  tags = {
    Name    = "healthcare-patient-records"
    Project = "Healthcare-Cloud-System"
  }
}

# =========================================================
# RDS SUBNET GROUP
# Two private subnets in different AZs
# =========================================================

resource "aws_db_subnet_group" "healthcare_db_subnet" {
  name = "healthcare-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "healthcare-db-subnet-group"
  }
}

# =========================================================
# RDS SECURITY GROUP
# =========================================================

resource "aws_security_group" "database_sg" {
  name        = "healthcare-database-sg"
  description = "Security group for healthcare RDS"
  vpc_id      = aws_vpc.healthcare_vpc.id

  ingress {
    description     = "MySQL from Web Server"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "healthcare-database-security-group"
  }
}

# =========================================================
# RDS MYSQL DATABASE
# =========================================================

resource "aws_db_instance" "healthcare_database" {
  identifier = "healthcare-database"

  engine         = "mysql"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 50

  db_name  = "healthcaredb"
  username = "admin"
  password = random_password.rds_password.result

  db_subnet_group_name = aws_db_subnet_group.healthcare_db_subnet.name

  vpc_security_group_ids = [
    aws_security_group.database_sg.id
  ]

  publicly_accessible = false

  backup_retention_period = 0

  skip_final_snapshot = true

  tags = {
    Name    = "healthcare-database"
    Project = "Healthcare-Cloud-System"
  }
}

# =========================================================
# OUTPUTS
# =========================================================

output "vpc_id" {
  value = aws_vpc.healthcare_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_1_id" {
  value = aws_subnet.private_subnet_1.id
}

output "private_subnet_2_id" {
  value = aws_subnet.private_subnet_2.id
}

output "ec2_instance_id" {
  value = aws_instance.healthcare_server.id
}

output "ec2_public_ip" {
  value = aws_instance.healthcare_server.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.healthcare_storage.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.patient_records.name
}

output "rds_endpoint" {
  value = aws_db_instance.healthcare_database.address
}

output "rds_port" {
  value = aws_db_instance.healthcare_database.port
}
