# Infraestructura AWS del backend

Terraform crea los recursos necesarios para completar el backend del CRUD:

- Lambda Function URL pública para el frontend.
- Tabla DynamoDB en modo `PAY_PER_REQUEST` con clave primaria `ID`.
- CORS configurado en la Function URL y también respondido por la Lambda.
- IAM role con permisos mínimos para DynamoDB y escritura en su log group.
- CloudWatch Log Group con retención configurable.

## Despliegue

```bash
cd Aws-Lambda/CRUD/clientes-aws/infra
terraform init
terraform apply \
  -var='aws_region=us-east-2' \
  -var='allowed_origins=["http://localhost:5173"]'
```

Para producción, reemplazá `allowed_origins` por el dominio donde publiques el frontend.

## Conectar el frontend

Después del `terraform apply`, copiá el output `clientes_api_url` en un archivo `.env` del frontend:

```bash
VITE_API_URL=https://xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.lambda-url.us-east-2.on.aws/
```

Luego ejecutá:

```bash
npm run build
```
