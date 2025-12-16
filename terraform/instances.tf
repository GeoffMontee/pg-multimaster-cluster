# EC2 Instances Configuration

locals {
  postgres_node_count = 3
  postgres_node_names = ["pg-node-1", "pg-node-2", "pg-node-3"]
}

# PostgreSQL Instances
resource "aws_instance" "postgres" {
  count = local.postgres_node_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.postgres_instance_type
  key_name               = aws_key_pair.cluster.key_name
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.postgres.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.postgres_root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-${var.environment}-${local.postgres_node_names[count.index]}-root"
    }
  }

  # PostgreSQL data volume
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = var.postgres_data_volume_size
    encrypted             = true
    delete_on_termination = true
    iops                  = 3000
    throughput            = 125

    tags = {
      Name = "${var.project_name}-${var.environment}-${local.postgres_node_names[count.index]}-data"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${local.postgres_node_names[count.index]}"
    Role = "postgresql"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# HAProxy Instance
resource "aws_instance" "haproxy" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.haproxy_instance_type
  key_name               = aws_key_pair.cluster.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.haproxy.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-${var.environment}-haproxy-root"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-haproxy"
    Role = "haproxy"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IPs for stable addressing (optional but recommended)
resource "aws_eip" "postgres" {
  count = local.postgres_node_count

  instance = aws_instance.postgres[count.index].id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-${local.postgres_node_names[count.index]}-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "haproxy" {
  instance = aws_instance.haproxy.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-haproxy-eip"
  }

  depends_on = [aws_internet_gateway.main]
}
