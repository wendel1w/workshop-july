# Valores do ambiente de workshop. Sem segredos: apenas identificacao e configuracao.
project     = "dvn-workshop-julho"
owner       = "wendel"
environment = "prd"
aws_region  = "us-east-1"
name_prefix = "dvn-wendel"

tags = {
  managed_by = "terraform"
  adr        = "ADR-003"
}

cluster = {
  version                 = "1.32"
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["0.0.0.0/0"]
  authentication_mode     = "API_AND_CONFIG_MAP"
  log_retention_in_days   = 14
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
}

node_group = {
  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
  ami_type       = "AL2023_x86_64_STANDARD"
  disk_size      = 20
  desired_size   = 2
  min_size       = 2
  max_size       = 2
}
