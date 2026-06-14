output "clientes_api_url" {
  description = "URL protegida de API Gateway para consumir el CRUD de clientes."
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/clientes"
}

output "clientes_table_name" {
  description = "Nombre de la tabla DynamoDB de clientes."
  value       = aws_dynamodb_table.clientes.name
}

output "cloudwatch_log_group" {
  description = "Log group de CloudWatch usado por la Lambda."
  value       = aws_cloudwatch_log_group.clientes_lambda.name
}

output "frontend_bucket_name" {
  description = "Bucket S3 del frontend."
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_cloudfront_url" {
  description = "URL pública del frontend en CloudFront."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "frontend_cloudfront_distribution_id" {
  description = "ID de la distribución de CloudFront del frontend."
  value       = aws_cloudfront_distribution.frontend.id
}

output "frontend_custom_domain_url" {
  description = "URL del dominio personalizado del frontend, si se configuró."
  value       = var.frontend_domain_name == "" ? null : "https://${var.frontend_domain_name}"
}

output "cognito_user_pool_id" {
  description = "ID del User Pool de Cognito."
  value       = aws_cognito_user_pool.clientes.id
}

output "cognito_frontend_client_id" {
  description = "Client ID público del frontend para Cognito Hosted UI."
  value       = aws_cognito_user_pool_client.frontend.id
}

output "cognito_domain" {
  description = "Dominio de Cognito Hosted UI."
  value       = "https://${aws_cognito_user_pool_domain.clientes.domain}.auth.${var.aws_region}.amazoncognito.com"
}