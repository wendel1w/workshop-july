# Valores do ambiente de workshop. Sem segredos: apenas identificacao e topologia.
project     = "dvn-workshop-julho"
owner       = "wendel"
environment = "prd"
aws_region  = "us-east-1"
name_prefix = "dvn-wendel"

tags = {
  managed_by = "terraform"
  adr        = "ADR-001"
}

vpc = {
  cidr_block = "10.0.0.0/24"

  public_subnets = {
    a = { cidr_block = "10.0.0.0/26", az_index = 0 }
    b = { cidr_block = "10.0.0.64/26", az_index = 1 }
  }

  private_subnets = {
    a = { cidr_block = "10.0.0.128/26", az_index = 0 }
    b = { cidr_block = "10.0.0.192/26", az_index = 1 }
  }
}

nat_gateway = {
  create            = true
  public_subnet_key = "a"
}

create_s3_endpoint = true

flow_log = {
  enabled           = true
  retention_in_days = 14
}
