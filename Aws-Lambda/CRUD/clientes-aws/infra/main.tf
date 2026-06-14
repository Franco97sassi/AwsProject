provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  lambda_name     = "${var.project_name}-api"
  lambda_src_dir  = "${path.module}/../backend/lambda/clientes"
  lambda_zip_path = "${path.module}/.terraform/${local.lambda_name}.zip"
  cognito_domain  = "clientesauth-${data.aws_caller_identity.current.account_id}"

  common_tags = {
    Project = var.project_name
    Level   = "2-backend-aws"
  }
}

data "aws_caller_identity" "current" {}

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
  authorization_type = "AWS_IAM"
}

resource "aws_lambda_permission" "allow_function_url" {
  statement_id           = "AllowFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.clientes_api.function_name
  principal              = "*"
  function_url_auth_type = "AWS_IAM"
}

resource "aws_cognito_user_pool" "clientes" {
  name = "${var.project_name}-users"

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  tags = merge(local.common_tags, {
    Level = "5-security"
  })
}

resource "aws_cognito_user_pool_client" "frontend" {
  name         = "${var.project_name}-frontend"
  user_pool_id = aws_cognito_user_pool.clientes.id

  allowed_oauth_flows                  = ["implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = var.cognito_callback_urls
  logout_urls                          = var.cognito_logout_urls
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  prevent_user_existence_errors        = "ENABLED"
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "clientes" {
  domain       = local.cognito_domain
  user_pool_id = aws_cognito_user_pool.clientes.id
}

resource "aws_apigatewayv2_api" "clientes" {
  name          = "${var.project_name}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["Authorization", "Content-Type"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins = var.allowed_origins
  }

  tags = merge(local.common_tags, {
    Level = "5-security"
  })
}

resource "aws_apigatewayv2_integration" "clientes_lambda" {
  api_id                 = aws_apigatewayv2_api.clientes.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.clientes_api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_authorizer" "clientes_cognito" {
  api_id           = aws_apigatewayv2_api.clientes.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project_name}-cognito"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.frontend.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.clientes.id}"
  }
}

resource "aws_apigatewayv2_route" "clientes" {
  api_id             = aws_apigatewayv2_api.clientes.id
  route_key          = "ANY /clientes"
  target             = "integrations/${aws_apigatewayv2_integration.clientes_lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.clientes_cognito.id
}
resource "aws_apigatewayv2_route" "clientes_options" {
  api_id    = aws_apigatewayv2_api.clientes.id
  route_key = "OPTIONS /clientes"
  target    = "integrations/${aws_apigatewayv2_integration.clientes_lambda.id}"
}
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.clientes.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.api_throttling_burst_limit
    throttling_rate_limit  = var.api_throttling_rate_limit
  }

  tags = merge(local.common_tags, {
    Level = "5-security"
  })
}

resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowHttpApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.clientes_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.clientes.execution_arn}/*/*"
}

locals {
  frontend_bucket_name = "${var.project_name}-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "frontend" {
  bucket = local.frontend_bucket_name

  tags = merge(local.common_tags, {
    Level = "4-frontend"
  })
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend-oac"
  description                       = "OAC para acceder al bucket S3 del frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = var.frontend_domain_name == "" ? [] : [var.frontend_domain_name]

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.frontend_domain_name == "" ? null : aws_acm_certificate_validation.frontend[0].certificate_arn
    cloudfront_default_certificate = var.frontend_domain_name == "" ? true : null
    minimum_protocol_version       = var.frontend_domain_name == "" ? null : "TLSv1.2_2021"
    ssl_support_method             = var.frontend_domain_name == "" ? null : "sni-only"
  }

  tags = merge(local.common_tags, {
    Level = "4-frontend"
  })

  depends_on = [
    aws_acm_certificate_validation.frontend
  ]
}

resource "aws_acm_certificate" "frontend" {
  count = var.frontend_domain_name == "" ? 0 : 1

  provider          = aws.us_east_1
  domain_name       = var.frontend_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Level = "4-frontend"
  })
}

resource "aws_route53_record" "frontend_certificate_validation" {
  for_each = var.frontend_domain_name == "" ? {} : {
    for option in aws_acm_certificate.frontend[0].domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_hosted_zone_id
}

resource "aws_acm_certificate_validation" "frontend" {
  count = var.frontend_domain_name == "" ? 0 : 1

  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.frontend[0].arn
  validation_record_fqdns = [for record in aws_route53_record.frontend_certificate_validation : record.fqdn]
}

resource "aws_route53_record" "frontend" {
  count = var.frontend_domain_name == "" ? 0 : 1

  name    = var.frontend_domain_name
  type    = "A"
  zone_id = var.route53_hosted_zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.lambda_name}-errors"
  alarm_description   = "Alarma cuando la Lambda registra errores."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.clientes_api.function_name
  }

  tags = merge(local.common_tags, {
    Level = "5-production"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.lambda_name}-throttles"
  alarm_description   = "Alarma cuando la Lambda tiene throttling."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.clientes_api.function_name
  }

  tags = merge(local.common_tags, {
    Level = "5-production"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${local.lambda_name}-duration"
  alarm_description   = "Alarma cuando la duración promedio de la Lambda supera el umbral configurado."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.lambda_duration_alarm_threshold_ms
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.clientes_api.function_name
  }

  tags = merge(local.common_tags, {
    Level = "5-production"
  })
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-api-5xx"
  alarm_description   = "Alarma cuando API Gateway devuelve respuestas 5xx."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.clientes.id
    Stage = aws_apigatewayv2_stage.default.name
  }

  tags = merge(local.common_tags, {
    Level = "5-production"
  })
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}