# Rule: Convenção de nomenclatura Terraform

**Escopo:** todo código Terraform deste repositório (`**/*.tf`, `**/*.tfvars`).
**Fonte:** https://www.terraform-best-practices.com/naming
**Decisão de origem:** `docs/adr-002-convencao-nomenclatura-terraform.md`

Princípio central: **`_` para o que o Terraform lê, `-` para o que humanos leem.**
Identificadores internos (recursos, data sources, variáveis, outputs, locals, módulos) em
`snake_case`; valores expostos a pessoas ou APIs (tag `Name`, nomes de recursos AWS, DNS)
em `kebab-case`.

Esta rule trata apenas de **nomenclatura**. Formatação (indentação, alinhamento) é
responsabilidade do `terraform fmt`.

## 1. Identificadores (regra geral)

- Use `_` (underscore) em todos os identificadores: nomes de recursos, data sources,
  variáveis, outputs, locals e módulos. Nunca `-`.
- Use apenas letras minúsculas e números, mesmo que o Terraform aceite UTF-8.

## 2. Recursos e data sources

- Não repita o tipo do recurso no nome do recurso, nem parcialmente.

  ```hcl
  resource "aws_route_table" "public" {}    # correto
  resource "aws_route_table" "public_route_table" {}  # incorreto
  ```

- Nomeie o recurso como `this` quando não houver nome mais descritivo, ou quando o
  módulo/stack cria um único recurso daquele tipo. Ex.: um só `aws_nat_gateway` → `this`;
  vários `aws_route_table` → `public`, `private`, `database`.
- Use sempre substantivos no **singular**.
- `count` / `for_each` é o **primeiro** argumento do bloco, seguido de uma linha em branco.
- `tags`, quando o recurso suportar, é o **último** argumento real, seguido por
  `depends_on` e `lifecycle` se existirem — cada um separado por uma linha em branco.
- Em `count`/`for_each` condicional, prefira variáveis booleanas explícitas
  (`var.create_nat_gateway ? 1 : 0`) a `length()` ou expressões indiretas.
- Use `-` dentro dos **valores** de argumentos que humanos ou APIs enxergam: tag `Name`,
  identificador de RDS, nome DNS, nome de bucket.

  ```hcl
  resource "aws_nat_gateway" "this" {
    count = var.create_nat_gateway ? 1 : 0

    allocation_id = aws_eip.nat[0].id
    subnet_id     = aws_subnet.this["public_a"].id

    tags = { Name = "dvn-wendel-natgw-a" }

    depends_on = [aws_internet_gateway.this]
  }
  ```

## 3. Variáveis

- Não reinvente nomes: reutilize nome, descrição e tipo do argumento do recurso
  correspondente.
- Use o **plural** quando o tipo for `list` ou `map`.
- Ordem das chaves no bloco: `description`, `type`, `default`, `validation`.
- `description` é obrigatória em toda variável.
- Declare o tipo mais específico possível (`map(object({...}))` em vez de `any`) e use
  `validation` quando houver domínio conhecido (CIDR válido, ambiente em `[dev, hml, prd]`).

## 4. Outputs

- Padrão de nome: `{name}_{type}_{attribute}` — `{name}` é o nome do recurso, **omitido
  quando for `this`**; `{type}` é o tipo abreviado; `{attribute}` é o atributo retornado.
  Ex.: `public_subnet_ids`, `nat_gateway_id`.
- Quando o valor agrega múltiplos recursos ou usa interpolação, `{name}`/`{type}` devem ser
  genéricos: `security_group_id`, não `this_security_group_id`.
- Use o **plural** quando o retorno for lista ou mapa.
- `description` é obrigatória em todo output.

## 5. Complemento deste projeto

Não faz parte do guia original; convenção interna definida no ADR-002.

- Valores de nome de recursos AWS: `dvn-wendel-<recurso>-<função>[-<az>]` em kebab-case.
  Ex.: `dvn-wendel-subnet-private-b`, `dvn-wendel-rtb-private`.
- Tags comuns (`Project`, `Environment`, `ManagedBy`, `Owner`) via `default_tags` no
  provider; nunca repetidas recurso a recurso. Chaves de tag em `PascalCase`, valores em
  kebab-case.
- Nomes de arquivo `.tf` agrupados por domínio, em palavra única ou kebab-case:
  `providers.tf`, `network.tf`, `endpoints.tf`, `observability.tf`, `variables.tf`,
  `outputs.tf`.
- Chaves de mapas consumidas por `for_each` seguem a §1 (`public_a`, `private_b`): elas
  entram no endereço do recurso no state.
- Nomes e tags não devem carregar informação sensível (nome de cliente, dado pessoal,
  identificador interno confidencial) — são legíveis por qualquer principal com permissão
  de `describe`.

## 6. Renomeação de recursos já provisionados

Renomear um recurso Terraform provoca destroy/create. Para recursos já existentes no
state, use `moved` blocks ou `terraform state mv` — nunca renomeie direto.

---

> **Pendência de validação:** o conteúdo das §1–§4 foi reproduzido de conhecimento prévio
> do guia; não houve acesso à URL no ambiente onde esta rule foi redigida. Confira item a
> item contra https://www.terraform-best-practices.com/naming e remova esta nota após a
> conferência.
