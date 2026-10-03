variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_ami" {
  description = "Amazon Linux 2023 AMI for Mumbai"
  type        = string
  default     = "ami-0f918f7e67a3323f0"
}

variable "s3_bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
}

variable "db_username" {
  description = "RDS username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}
