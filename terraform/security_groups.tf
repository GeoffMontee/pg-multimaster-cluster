# Security Groups Configuration

# Security Group for PostgreSQL Servers
resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-postgres-sg"
  description = "Security group for PostgreSQL servers"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # PostgreSQL from HAProxy
  ingress {
    description     = "PostgreSQL from HAProxy"
    from_port       = var.postgres_port
    to_port         = var.postgres_port
    protocol        = "tcp"
    security_groups = [aws_security_group.haproxy.id]
  }

  # PostgreSQL from other PostgreSQL servers (for replication)
  ingress {
    description = "PostgreSQL replication between nodes"
    from_port   = var.postgres_port
    to_port     = var.postgres_port
    protocol    = "tcp"
    self        = true
  }

  # RepMgr daemon port
  ingress {
    description = "RepMgr daemon"
    from_port   = 5433
    to_port     = 5433
    protocol    = "tcp"
    self        = true
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres-sg"
  }
}

# Security Group for HAProxy
resource "aws_security_group" "haproxy" {
  name        = "${var.project_name}-${var.environment}-haproxy-sg"
  description = "Security group for HAProxy load balancer"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # HAProxy PostgreSQL port
  ingress {
    description = "PostgreSQL load balanced port"
    from_port   = var.haproxy_postgres_port
    to_port     = var.haproxy_postgres_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_postgres_cidrs
  }

  # HAProxy stats port
  ingress {
    description = "HAProxy statistics"
    from_port   = var.haproxy_stats_port
    to_port     = var.haproxy_stats_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs # Restrict to admins
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-haproxy-sg"
  }
}
