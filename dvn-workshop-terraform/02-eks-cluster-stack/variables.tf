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
  description = "Regiao AWS onde os recursos serao provisionados."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefixo em kebab-case usado nos valores de nome (tag Name) dos recursos AWS."
  type        = string
  default     = "dvn-wendel"
}

variable "tags" {
  description = "Tags comuns aplicadas a todos os recursos via default_tags do provider."

  type = object({
    managed_by = optional(string, "terraform")
    adr        = optional(string, "ADR-003")
  })

  default = {}
}

variable "cluster" {
  description = "Configuracao do cluster EKS: versao do Kubernetes, log types, endpoint access e authentication mode."

  type = object({
    version                 = optional(string, "1.32")
    endpoint_private_access = optional(bool, true)
    endpoint_public_access  = optional(bool, true)
    public_access_cidrs     = optional(list(string), ["0.0.0.0/0"])
    authentication_mode     = optional(string, "API_AND_CONFIG_MAP")
    log_retention_in_days   = optional(number, 14)
    enabled_cluster_log_types = optional(list(string), [
      "api",
      "audit",
      "authenticator",
      "controllerManager",
      "scheduler"
    ])
  })

  default = {}

  validation {
    condition     = contains(["API", "CONFIG_MAP", "API_AND_CONFIG_MAP"], var.cluster.authentication_mode)
    error_message = "cluster.authentication_mode deve ser um de: API, CONFIG_MAP, API_AND_CONFIG_MAP."
  }
}

variable "node_group" {
  description = "Configuracao do Managed Node Group: instance type, capacidade e sizing."

  type = object({
    instance_types = optional(list(string), ["t3.medium"])
    capacity_type  = optional(string, "ON_DEMAND")
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    disk_size      = optional(number, 20)
    desired_size   = optional(number, 2)
    min_size       = optional(number, 2)
    max_size       = optional(number, 2)
  })

  default = {}

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_group.capacity_type)
    error_message = "node_group.capacity_type deve ser ON_DEMAND ou SPOT."
  }

  validation {
    condition     = var.node_group.min_size <= var.node_group.desired_size && var.node_group.desired_size <= var.node_group.max_size
    error_message = "node_group: min_size <= desired_size <= max_size."
  }
}
