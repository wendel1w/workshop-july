resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.flow_log.enabled ? 1 : 0

  name              = "/aws/vpc/${var.name_prefix}-flow-log"
  retention_in_days = var.flow_log.retention_in_days

  tags = {
    Name = "${var.name_prefix}-log-group-flow-log"
  }
}

data "aws_iam_policy_document" "flow_log_assume" {
  statement {
    sid     = "AllowVpcFlowLogsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

# Least privilege: apenas escrita no log group deste stack, sem Resource "*".
data "aws_iam_policy_document" "flow_log" {
  count = var.flow_log.enabled ? 1 : 0

  statement {
    sid    = "AllowWriteToFlowLogGroup"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = ["${aws_cloudwatch_log_group.flow_log[0].arn}:*"]
  }
}

resource "aws_iam_role" "flow_log" {
  count = var.flow_log.enabled ? 1 : 0

  name               = "${var.name_prefix}-role-flow-log"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume.json

  tags = {
    Name = "${var.name_prefix}-role-flow-log"
  }
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.flow_log.enabled ? 1 : 0

  name   = "${var.name_prefix}-policy-flow-log"
  role   = aws_iam_role.flow_log[0].id
  policy = data.aws_iam_policy_document.flow_log[0].json
}

resource "aws_flow_log" "this" {
  count = var.flow_log.enabled ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_log[0].arn
  iam_role_arn             = aws_iam_role.flow_log[0].arn
  max_aggregation_interval = 600

  tags = {
    Name = "${var.name_prefix}-flow-log"
  }
}
