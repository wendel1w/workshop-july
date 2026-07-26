variable "project" {
  description = "Nome do projeto, usado na tag Project."
  type        = string
  default     = "dvn-workshop-julho"
}

variable "owner" {
  description = "Responsavel pelos recursos, usado na tag Owner."
  type        = string
  default     = "wendel"
}

variable "environment" {
  description = "Ambiente de destino do stack."
  type        = string
  default     = "prd"

  validation {
    condition     = contains(["dev", "hml", "prd"], var.environment)
    error_message = "environment deve ser um de: dev, hml, prd."
  }
}

variable "aws_region" {
  description = "Regiao AWS do bucket de state."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Tags comuns aplicadas via default_tags do provider."

  type = object({
    managed_by = optional(string, "terraform")
  })

  default = {}
}

# Dominio unico do bucket de state: nome, configuracoes de seguranca e lifecycle.
variable "state_bucket" {
  description = "Configuracao do bucket S3 usado como backend remoto para os states Terraform do projeto."

  type = object({
    name                               = string
    force_destroy                      = optional(bool, false)
    versioning_enabled                 = optional(bool, true)
    block_public_access                = optional(bool, true)
    noncurrent_version_expiration_days = optional(number, 90)
  })

  default = {
    name = "dvn-wendel-tfstate-us-east-1"
  }

  validation {
    condition     = length(var.state_bucket.name) >= 3 && length(var.state_bucket.name) <= 63
    error_message = "state_bucket.name deve ter entre 3 e 63 caracteres."
  }
}
