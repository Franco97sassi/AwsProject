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
