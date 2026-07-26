# EKS Managed Node Group — Worker Nodes On-Demand.
# Nodes provisionados nas subnets privadas, sem IP publico, com AMI gerenciada pela AWS.

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = local.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = values(local.private_subnet_ids)

  instance_types = var.node_group.instance_types
  capacity_type  = var.node_group.capacity_type
  ami_type       = var.node_group.ami_type
  disk_size      = var.node_group.disk_size

  scaling_config {
    desired_size = var.node_group.desired_size
    min_size     = var.node_group.min_size
    max_size     = var.node_group.max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = local.node_group_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_read_only,
  ]
}
