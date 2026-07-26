variable "project" {
  description = "Nome do projeto, usado na tag Project e na composicao dos nomes de recursos."
  type        = string
  default     = "dvn-workshop"
}

variable "owner" {
  description = "Responsavel pelos recursos, usado na tag Owner."
  type        = string
  default     = "wendel"
}

variable "environment" {
  description = "Ambiente de destino do stack."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "hml", "prd"], var.environment)
    error_message = "environment deve ser um de: dev, hml, prd."
  }
}

variable "aws_region" {
  description = "Regiao AWS onde a rede sera provisionada."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefixo em kebab-case usado nos valores de nome (tag Name) dos recursos AWS, conforme .kiro/rules/terraform-naming.md secao 5."
  type        = string
  default     = "dvn-wendel"
}

# Tags comuns aplicadas via default_tags no provider (.kiro/rules/terraform-naming.md
# secao 5: nunca repetidas recurso a recurso). Agrupadas em um unico objeto por
# pertencerem ao mesmo dominio (identificacao do stack), conforme
# .kiro/rules/terraform-variable-structure.md.
variable "tags" {
  description = "Tags comuns aplicadas a todos os recursos via default_tags do provider."

  type = object({
    managed_by = optional(string, "terraform")
    adr        = optional(string, "ADR-001")
  })

  default = {}
}

# Domínio único da VPC: CIDR, flags de DNS e as duas coleções de subnets, conforme
# .kiro/rules/terraform-variable-structure.md (variáveis contextualizadas, não isoladas).
variable "vpc" {
  description = "Definicao completa da VPC: CIDR, flags de DNS e subnets publicas/privadas, cada uma indexada pelo sufixo da AZ."

  type = object({
    cidr_block           = string
    enable_dns_support   = optional(bool, true)
    enable_dns_hostnames = optional(bool, true)

    public_subnets = map(object({
      cidr_block = string
      az_index   = number
    }))

    private_subnets = map(object({
      cidr_block = string
      az_index   = number
    }))
  })

  default = {
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

  validation {
    condition     = can(cidrnetmask(var.vpc.cidr_block))
    error_message = "vpc.cidr_block deve ser um CIDR IPv4 valido."
  }

  validation {
    condition = alltrue(concat(
      [for subnet in var.vpc.public_subnets : can(cidrnetmask(subnet.cidr_block))],
      [for subnet in var.vpc.private_subnets : can(cidrnetmask(subnet.cidr_block))],
    ))
    error_message = "Todo cidr_block em vpc.public_subnets e vpc.private_subnets deve ser um CIDR IPv4 valido."
  }
}

# Domínio único do NAT Gateway: qual subnet publica o hospeda e se ele deve existir.
variable "nat_gateway" {
  description = "Configuracao do NAT Gateway unico da rede."

  type = object({
    create            = optional(bool, true)
    public_subnet_key = optional(string, "a")
  })

  default = {}
}

variable "create_s3_endpoint" {
  description = "Cria o VPC Endpoint Gateway para S3 associado a route table privada."
  type        = bool
  default     = true
}

# Domínio único do Flow Log: habilitação e retenção juntas.
variable "flow_log" {
  description = "Configuracao dos VPC Flow Logs publicados em CloudWatch Logs."

  type = object({
    enabled           = optional(bool, true)
    retention_in_days = optional(number, 14)
  })

  default = {}
}
