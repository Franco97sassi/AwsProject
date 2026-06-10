provider "aws" {
  region = var.aws_region
}

locals {
  lambda_name     = "${var.project_name}-api"
  lambda_src_dir  = "${path.module}/../backend/lambda/clientes"
  lambda_zip_path = "${path.module}/.terraform/${local.lambda_name}.zip"
  common_tags = {
    Project = var.project_name
    Level   = "2-backend-aws"
  }
}

data "archive_file" "clientes_lambda" {
  type        = "zip"
  source_dir  = local.lambda_src_dir
  output_path = local.lambda_zip_path
}

resource "aws_dynamodb_table" "clientes" {
  name         = "${var.project_name}-clientes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ID"

  attribute {
    name = "ID"
    type = "S"
  }

  tags = local.common_tags
}

resource "aws_iam_role" "lambda_exec" {
  name = "${local.lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "clientes_lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_minimum_permissions" {
  name = "${local.lambda_name}-minimum-permissions"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ClientesTableCrud"
        Effect = "Allow"
        Action = [
          "dynamodb:DeleteItem",
          "dynamodb:PutItem",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.clientes.arn
      },
      {
        Sid    = "WriteLambdaLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.clientes_lambda.arn}:*"
      }
    ]
  })
}

resource "aws_lambda_function" "clientes_api" {
  function_name    = local.lambda_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.clientes_lambda.output_path
  source_code_hash = data.archive_file.clientes_lambda.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME      = aws_dynamodb_table.clientes.name
      ALLOWED_ORIGINS = join(",", var.allowed_origins)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.clientes_lambda,
    aws_iam_role_policy.lambda_minimum_permissions,
  ]

  tags = local.common_tags
}

resource "aws_lambda_function_url" "clientes_api" {
  function_name      = aws_lambda_function.clientes_api.function_name
  authorization_type = "NONE"

  depends_on = [
    aws_lambda_permission.allow_public_function_url
  ]
}

resource "aws_lambda_permission" "allow_public_function_url" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.clientes_api.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
 