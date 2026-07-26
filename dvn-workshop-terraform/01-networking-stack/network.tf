resource "aws_vpc" "this" {
  cidr_block           = var.vpc.cidr_block
  enable_dns_support   = var.vpc.enable_dns_support
  enable_dns_hostnames = var.vpc.enable_dns_hostnames

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = var.vpc.public_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = data.aws_availability_zones.available.names[each.value.az_index]

  # IP publico e opt-in explicito no recurso que precisar (ADR-001 secao 6).
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-subnet-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = var.vpc.private_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr_block
  availability_zone       = data.aws_availability_zones.available.names[each.value.az_index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-subnet-private-${each.key}"
    Tier = "private"
  }
}

resource "aws_eip" "nat" {
  count = var.nat_gateway.create ? 1 : 0

  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-eip-natgw-${var.nat_gateway.public_subnet_key}"
  }
}

resource "aws_nat_gateway" "this" {
  count = var.nat_gateway.create ? 1 : 0

  allocation_id     = aws_eip.nat[0].id
  subnet_id         = aws_subnet.public[var.nat_gateway.public_subnet_key].id
  connectivity_type = "public"

  tags = {
    Name = "${var.name_prefix}-natgw-${var.nat_gateway.public_subnet_key}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-rtb-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-rtb-private"
  }
}

# Route table privada unica compartilhada pelas duas AZs: o trafego da AZ b atravessa AZ
# para alcancar o NAT na AZ a (ADR-001 opcao H e risco R1).
resource "aws_route" "private_nat" {
  count = var.nat_gateway.create ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
