output "vpc_id" {
  description = "ID da VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Bloco CIDR IPv4 da VPC."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID do Internet Gateway anexado a VPC."
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas, indexados pela chave da subnet."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas, indexados pela chave da subnet."
  value       = { for key, subnet in aws_subnet.private : key => subnet.id }
}

output "nat_gateway_id" {
  description = "ID do NAT Gateway unico, ou null quando create_nat_gateway for false."
  value       = one(aws_nat_gateway.this[*].id)
}

output "nat_eip_public_ip" {
  description = "Endereco IPv4 publico do Elastic IP do NAT Gateway, ou null quando create_nat_gateway for false."
  value       = one(aws_eip.nat[*].public_ip)
}

output "public_route_table_id" {
  description = "ID da route table das subnets publicas."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID da route table das subnets privadas."
  value       = aws_route_table.private.id
}

output "s3_vpc_endpoint_id" {
  description = "ID do VPC Endpoint Gateway para S3, ou null quando create_s3_endpoint for false."
  value       = one(aws_vpc_endpoint.s3[*].id)
}

output "default_security_group_id" {
  description = "ID do default Security Group da VPC, mantido sem regras."
  value       = aws_default_security_group.this.id
}

output "flow_log_cloudwatch_log_group_name" {
  description = "Nome do CloudWatch Log Group dos VPC Flow Logs, ou null quando enable_flow_log for false."
  value       = one(aws_cloudwatch_log_group.flow_log[*].name)
}
