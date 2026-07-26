# EKS Cluster — Control Plane Kubernetes.
# Autenticacao dual-mode (API_AND_CONFIG_MAP), logs completos, endpoints publico + privado.

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  version  = var.cluster.version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = values(local.private_subnet_ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = var.cluster.endpoint_private_access
    endpoint_public_access  = var.cluster.endpoint_public_access
    public_access_cidrs     = var.cluster.public_access_cidrs
  }

  access_config {
    authentication_mode = var.cluster.authentication_mode
  }

  enabled_cluster_log_types = var.cluster.enabled_cluster_log_types

  tags = {
    Name = local.cluster_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_eks_policy,
    aws_cloudwatch_log_group.cluster,
  ]
}
