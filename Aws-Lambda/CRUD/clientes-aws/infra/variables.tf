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
