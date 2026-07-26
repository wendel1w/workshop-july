# Valores do bootstrap de state remoto. Sem segredos.
project     = "dvn-workshop-julho"
owner       = "wendel"
environment = "prd"
aws_region  = "us-east-1"

state_bucket = {
  name                               = "dvn-wendel-tfstate-us-east-1"
  force_destroy                      = false
  versioning_enabled                 = true
  block_public_access                = true
  noncurrent_version_expiration_days = 90
}
