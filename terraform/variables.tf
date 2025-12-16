# Variable definitions for PostgreSQL HA Cluster

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Owner tag for AWS resources (required by account policy)"
  type        = string
  # No default - must be provided
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "pg-ha"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

variable "postgres_instance_type" {
  description = "EC2 instance type for PostgreSQL servers"
  type        = string
  default     = "t3.medium"
}

variable "haproxy_instance_type" {
  description = "EC2 instance type for HAProxy server"
  type        = string
  default     = "t3.small"
}

variable "postgres_root_volume_size" {
  description = "Root volume size in GB for PostgreSQL instances"
  type        = number
  default     = 30
}

variable "postgres_data_volume_size" {
  description = "Data volume size in GB for PostgreSQL instances"
  type        = number
  default     = 100
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "allowed_postgres_cidrs" {
  description = "CIDR blocks allowed to connect to PostgreSQL via HAProxy"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "haproxy_postgres_port" {
  description = "HAProxy port for PostgreSQL load balancing"
  type        = number
  default     = 5000
}

variable "haproxy_stats_port" {
  description = "HAProxy statistics port"
  type        = number
  default     = 7000
}
