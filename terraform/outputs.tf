# Terraform Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "postgres_instance_ids" {
  description = "PostgreSQL instance IDs"
  value       = aws_instance.postgres[*].id
}

output "postgres_private_ips" {
  description = "PostgreSQL private IP addresses"
  value       = aws_instance.postgres[*].private_ip
}

output "postgres_public_ips" {
  description = "PostgreSQL public IP addresses (Elastic IPs)"
  value       = aws_eip.postgres[*].public_ip
}

output "haproxy_instance_id" {
  description = "HAProxy instance ID"
  value       = aws_instance.haproxy.id
}

output "haproxy_private_ip" {
  description = "HAProxy private IP address"
  value       = aws_instance.haproxy.private_ip
}

output "haproxy_public_ip" {
  description = "HAProxy public IP address (Elastic IP)"
  value       = aws_eip.haproxy.public_ip
}

output "ssh_key_file" {
  description = "Path to SSH private key"
  value       = local_file.private_key.filename
}

output "connection_string" {
  description = "PostgreSQL connection string via HAProxy"
  value       = "postgresql://user:password@${aws_eip.haproxy.public_ip}:${var.haproxy_postgres_port}/dbname"
  sensitive   = true
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.yml.tpl", {
    postgres_nodes = [
      for i, instance in aws_instance.postgres : {
        name       = "pg-node-${i + 1}"
        public_ip  = aws_eip.postgres[i].public_ip
        private_ip = instance.private_ip
        node_id    = i + 1
      }
    ]
    haproxy_node = {
      name       = "haproxy"
      public_ip  = aws_eip.haproxy.public_ip
      private_ip = aws_instance.haproxy.private_ip
    }
    ssh_key_file    = "../ansible/ssh_key.pem"
    postgres_port   = var.postgres_port
    haproxy_port    = var.haproxy_postgres_port
    stats_port      = var.haproxy_stats_port
  })
  filename = "${path.module}/../ansible/inventory/hosts.yml"
}

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory"
  value       = local_file.ansible_inventory.filename
}

output "haproxy_stats_url" {
  description = "HAProxy statistics URL"
  value       = "http://${aws_eip.haproxy.public_ip}:${var.haproxy_stats_port}/stats"
}
