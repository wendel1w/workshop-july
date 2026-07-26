# Valores do ambiente de workshop. Sem segredos: apenas identificacao e configuracao.
project     = "dvn-workshop-julho"
owner       = "wendel"
environment = "prd"
aws_region  = "us-east-1"
name_prefix = "dvn-wendel"

tags = {
  managed_by = "terraform"
  adr        = "ADR-004"
}

# GitHub — ajustar org/usuario conforme o repositorio real.
github_org    = "wendel1w"
github_repo   = "workshop-july"
github_branch = "main"

ecr_repositories = [
  "dvn-workshop/backend",
  "dvn-workshop/frontend"
]
