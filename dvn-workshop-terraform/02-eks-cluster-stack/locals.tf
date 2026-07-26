locals {
  cluster_name    = "${var.name_prefix}-eks"
  log_group_name  = "/aws/eks/${local.cluster_name}/cluster"
  node_group_name = "${local.cluster_name}-ng-on-demand"

  # IDs das subnets privadas do stack de networking (mapa chave => id).
  private_subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids

  # VPC ID do stack de networking.
  vpc_id = data.terraform_remote_state.networking.outputs.vpc_id

  # IDs das subnets publicas do stack de networking (para tags do EKS).
  public_subnet_ids = data.terraform_remote_state.networking.outputs.public_subnet_ids
}
