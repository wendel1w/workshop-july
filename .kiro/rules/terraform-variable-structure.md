# Rule: Estruturação de variáveis Terraform

**Escopo:** todo código Terraform deste repositório (`**/*.tf`, `**/*.tfvars`).
**Decisão de origem:** instrução direta do usuário em 2026-07-25. Sem ADR próprio — é
convenção de código, não decisão de arquitetura.

Esta rule trata de **como agrupar variáveis**. Para nomes de identificadores, ver
`.kiro/rules/terraform-naming.md`.

## 1. Princípios

- **Nada de valor mágico inline.** Todo CIDR, nome, flag, número de retenção etc. vem de
  `var` ou `local` — nunca literal direto no `resource`/`data`.
- **Nada de string hardcoded fora de variável.** Se um valor pode mudar entre ambientes ou
  se repete em mais de um lugar, é variável.
- **Variáveis contextualizadas, não isoladas.** Não crie uma variável "solteira" por
  atributo quando os atributos pertencem ao mesmo conceito de domínio. Agrupe em `object`
  ou `list(object(...))`/`map(object(...))` conforme a cardinalidade.
- Isolar variáveis de conceitos que já formam uma unidade (ex.: uma variável para CIDR da
  subnet pública e outra separada para o nome da mesma subnet) fragmenta o domínio e
  dificulta manter os atributos em sincronia.

## 2. Como decidir a forma

| Situação | Forma | Exemplo |
|---|---|---|
| Um conceito único, atributos fixos, ocorre uma vez no stack | `object({...})` | `variable "vpc" { type = object({ cidr_block = string, enable_dns_support = bool, ... }) }` |
| Uma coleção do mesmo conceito, quantidade variável, sem chave natural | `list(object({...}))` | lista de subnets com `name`, `cidr_block`, `az_index`, `public` |
| Uma coleção do mesmo conceito, quantidade variável, com chave natural (referenciada por `for_each`) | `map(object({...}))` | mapa de subnets indexado por sufixo de AZ |
| Vários conceitos relacionados que compõem um domínio maior | `object` com atributos aninhados (`object`/`list`/`map` dentro de `object`) | uma única `variable "vpc"` contendo `cidr_block` e a lista/mapa de subnets |

Regra prática: se ao ler o `.tfvars` um humano entende a topologia completa de um domínio
(ex.: a VPC inteira) num único bloco, a estrutura está correta. Se precisa pular entre
5 variáveis desconectadas para montar o mesmo entendimento, está fragmentada.

## 3. Exemplo — correto vs. incorreto

**Incorreto — variáveis isoladas por atributo, uma por camada:**

```hcl
variable "vpc_cidr_block" {
  type = string
}

variable "public_subnets" {
  type = map(object({ cidr_block = string, az_index = number }))
}

variable "private_subnets" {
  type = map(object({ cidr_block = string, az_index = number }))
}
```

**Correto — um único domínio `vpc`, com as subnets como atributo aninhado:**

```hcl
variable "vpc" {
  description = "Definicao completa da VPC: CIDR, flags de DNS e subnets publicas/privadas."

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

  validation {
    condition     = can(cidrnetmask(var.vpc.cidr_block))
    error_message = "vpc.cidr_block deve ser um CIDR IPv4 valido."
  }
}
```

Consumo no recurso, sem valor mágico inline:

```hcl
resource "aws_subnet" "public" {
  for_each = var.vpc.public_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = data.aws_availability_zones.available.names[each.value.az_index]
}
```

## 4. Limites da regra

- Não agrupe conceitos **sem relação de domínio** só para reduzir a contagem de
  variáveis (ex.: não misturar configuração de VPC com configuração de IAM na mesma
  `object`). O agrupamento segue o domínio, não a conveniência.
- Flags globais do stack que não pertencem a nenhum domínio específico (ex.:
  `environment`, `project`, `owner`) continuam como variáveis simples de topo — elas não
  têm "irmãos" para formar um objeto.
- Continua valendo `.kiro/rules/terraform-naming.md` §3: nome, tipo e ordem de chaves
  (`description`, `type`, `default`, `validation`) de cada `variable`.
