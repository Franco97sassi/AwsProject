variable "aws_region" {
  description = "Región de AWS donde se desplegará el backend."
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Prefijo usado para nombrar los recursos de AWS."
  type        = string
  default     = "clientes-aws"
}

variable "allowed_origins" {
  description = "Lista de orígenes permitidos por CORS."
  type        = list(string)
  default = [
    "http://localhost:5173",
    "https://d3b5ais4i62a9v.cloudfront.net"
  ]
}

variable "log_retention_days" {
  description = "Días de retención para los logs de CloudWatch."
  type        = number
  default     = 14
}

variable "frontend_domain_name" {
  description = "Dominio personalizado opcional para CloudFront. Dejar vacío para usar el dominio default de CloudFront."
  type        = string
  default     = ""
}

variable "route53_hosted_zone_id" {
  description = "ID de la hosted zone de Route 53 donde se creará el alias del frontend. Obligatorio si frontend_domain_name no está vacío."
  type        = string
  default     = ""

  validation {
    condition     = var.frontend_domain_name == "" || var.route53_hosted_zone_id != ""
    error_message = "route53_hosted_zone_id es obligatorio cuando frontend_domain_name no está vacío."
  }
}

variable "cognito_callback_urls" {
  description = "URLs permitidas para el callback de Cognito Hosted UI."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

variable "cognito_logout_urls" {
  description = "URLs permitidas para logout de Cognito Hosted UI."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

variable "api_throttling_burst_limit" {
  description = "Límite burst de throttling para API Gateway HTTP API."
  type        = number
  default     = 50
}

variable "api_throttling_rate_limit" {
  description = "Límite sostenido de requests por segundo para API Gateway HTTP API."
  type        = number
  default     = 25
}

variable "lambda_duration_alarm_threshold_ms" {
  description = "Umbral de duración promedio de Lambda, en milisegundos, para disparar alarma."
  type        = number
  default     = 3000
}