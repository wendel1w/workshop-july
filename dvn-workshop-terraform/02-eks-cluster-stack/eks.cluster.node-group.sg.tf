# Security Group dos Worker Nodes.
# Permite comunicacao com o control plane, inter-node e saida para internet (via NAT).

resource "aws_security_group" "node" {
  name        = "${var.name_prefix}-sg-eks-node"
  description = "Security group para os worker nodes do EKS"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${var.name_prefix}-sg-eks-node"
  }
}

# Ingress: control plane pode se comunicar com os nodes na porta 443 (webhook, metrics).
resource "aws_security_group_rule" "node_ingress_cluster_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow cluster control plane to communicate with nodes (HTTPS)"
}

# Ingress: control plane pode se comunicar com os nodes nas portas altas (kubelet, extensoes).
resource "aws_security_group_rule" "node_ingress_cluster_high_ports" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow cluster control plane to communicate with nodes (high ports)"
}

# Ingress: comunicacao inter-node (todos os protocolos entre nodes do mesmo SG).
resource "aws_security_group_rule" "node_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  self              = true
  description       = "Allow inter-node communication"
}

# Egress: nodes podem acessar qualquer destino (pull de imagens, APIs AWS via NAT).
resource "aws_security_group_rule" "node_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from nodes"
}
