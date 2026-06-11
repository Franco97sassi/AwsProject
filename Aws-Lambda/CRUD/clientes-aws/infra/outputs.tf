output "clientes_api_url" {
  description = "URL pública de la Lambda Function URL"
  value       = aws_lambda_function_url.clientes_api.function_url
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
  description = "Bucket S3 del frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_cloudfront_url" {
  description = "URL pública del frontend en CloudFront"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}