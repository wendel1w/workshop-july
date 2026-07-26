# Tags nas subnets para descoberta automatica pelo EKS e AWS Load Balancer Controller.
# Adicionadas via aws_ec2_tag para evitar alterar o stack 01-networking-stack.

# Subnets privadas: marcadas para internal ELB e associacao ao cluster.
resource "aws_ec2_tag" "private_subnet_cluster" {
  for_each = local.private_subnet_ids

  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each = local.private_subnet_ids

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

# Subnets publicas: marcadas para external ELB e associacao ao cluster.
resource "aws_ec2_tag" "public_subnet_cluster" {
  for_each = local.public_subnet_ids

  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "public_subnet_elb" {
  for_each = local.public_subnet_ids

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
