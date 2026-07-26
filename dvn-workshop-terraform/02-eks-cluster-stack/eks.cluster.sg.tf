# Security Group do EKS Control Plane.
# Permite comunicacao bidirecional entre control plane e worker nodes.

resource "aws_security_group" "cluster" {
  name        = "${var.name_prefix}-sg-eks-cluster"
  description = "Security group para o EKS control plane"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${var.name_prefix}-sg-eks-cluster"
  }
}

# Ingress: nodes podem se comunicar com o API server na porta 443.
resource "aws_security_group_rule" "cluster_ingress_nodes_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description              = "Allow nodes to communicate with the cluster API server"
}

# Egress: control plane pode se comunicar com nodes (kubelet e extensoes) nas portas 443 e 1025-65535.
resource "aws_security_group_rule" "cluster_egress_nodes_https" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description              = "Allow cluster control plane to communicate with nodes (HTTPS)"
}

resource "aws_security_group_rule" "cluster_egress_nodes_high_ports" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description              = "Allow cluster control plane to communicate with nodes (high ports)"
}
