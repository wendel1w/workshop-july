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
    adr        = optional(string, "ADR-004")
  })

  default = {}
}

variable "github_org" {
  description = "Organizacao ou usuario do GitHub que detém o repositorio de aplicações."
  type        = string
  default     = "wendel1w"
}

variable "github_repo" {
  description = "Nome do repositorio GitHub das aplicações (sem a org)."
  type        = string
  default     = "workshop-july"
}

variable "github_branch" {
  description = "Branch que pode assumir a role via OIDC. Usado na trust policy."
  type        = string
  default     = "main"
}

variable "ecr_repositories" {
  description = "Lista dos nomes dos repositorios ECR que a role de CI pode fazer push."
  type        = list(string)
  default     = ["dvn-workshop/backend", "dvn-workshop/frontend"]
}
