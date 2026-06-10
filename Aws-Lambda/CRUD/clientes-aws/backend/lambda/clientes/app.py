import base64
import json
import logging
import os
import uuid
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["TABLE_NAME"]
ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.environ.get("ALLOWED_ORIGINS", "*").split(",")
    if origin.strip()
]

table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    logger.info("request_id=%s event=%s", context.aws_request_id, json.dumps(event))

    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")

    if method == "OPTIONS":
        return response(204, None, event)

    try:
        if method == "GET":
            return listar_clientes(event)

        if method == "POST":
            return crear_cliente(event)

        if method == "PUT":
            return actualizar_cliente(event)

        if method == "DELETE":
            return eliminar_cliente(event)

        return response(405, {"message": "Método no permitido"}, event)
    except ValueError as exc:
        return response(400, {"message": str(exc)}, event)
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return response(404, {"message": "Cliente no encontrado"}, event)

        logger.exception("Error de DynamoDB")
        return response(
            500,
            {"message": "No se pudo completar la operación en DynamoDB"},
            event,
        )
    except Exception:
        logger.exception("Error inesperado")
        return response(500, {"message": "Error interno del servidor"}, event)


def listar_clientes(event):
    result = table.scan()
    clientes = result.get("Items", [])

    while "LastEvaluatedKey" in result:
        result = table.scan(ExclusiveStartKey=result["LastEvaluatedKey"])
        clientes.extend(result.get("Items", []))

    clientes.sort(key=lambda cliente: cliente.get("createdAt", ""), reverse=True)
    return response(200, clientes, event)


def crear_cliente(event):
    body = parse_body(event)
    nombre = clean_required_text(body, "nombre")
    apellido = clean_required_text(body, "apellido")

    cliente = {
        "ID": str(uuid.uuid4()),
        "nombre": nombre,
        "apellido": apellido,
        "createdAt": event.get("requestContext", {}).get("timeEpoch"),
    }

    table.put_item(
        Item=cliente,
        ConditionExpression="attribute_not_exists(ID)",
    )

    return response(201, cliente, event)


def actualizar_cliente(event):
    cliente_id = get_client_id(event)
    body = parse_body(event)
    nombre = clean_required_text(body, "nombre")
    apellido = clean_required_text(body, "apellido")

    result = table.update_item(
        Key={"ID": cliente_id},
        UpdateExpression="SET nombre = :nombre, apellido = :apellido, updatedAt = :updatedAt",
        ConditionExpression="attribute_exists(ID)",
        ExpressionAttributeValues={
            ":nombre": nombre,
            ":apellido": apellido,
            ":updatedAt": event.get("requestContext", {}).get("timeEpoch"),
        },
        ReturnValues="ALL_NEW",
    )

    return response(200, result["Attributes"], event)


def eliminar_cliente(event):
    cliente_id = get_client_id(event)

    table.delete_item(
        Key={"ID": cliente_id},
        ConditionExpression="attribute_exists(ID)",
    )

    return response(204, None, event)


def parse_body(event):
    raw_body = event.get("body")

    if not raw_body:
        raise ValueError("El body JSON es obligatorio")

    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(raw_body).decode("utf-8")

    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise ValueError("El body debe ser JSON válido") from exc

    if not isinstance(body, dict):
        raise ValueError("El body debe ser un objeto JSON")

    return body


def clean_required_text(body, field_name):
    value = body.get(field_name)

    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"El campo {field_name} es obligatorio")

    value = value.strip()

    if len(value) < 2:
        raise ValueError(f"El campo {field_name} debe tener al menos 2 caracteres")

    return value


def get_client_id(event):
    params = event.get("queryStringParameters") or {}
    cliente_id = params.get("id") or params.get("ID")

    if not cliente_id:
        raise ValueError("El parámetro id es obligatorio")

    return cliente_id


def response(status_code, body, event):
    headers = cors_headers(event)

    if body is None:
        return {"statusCode": status_code, "headers": headers, "body": ""}

    headers["Content-Type"] = "application/json"

    return {
        "statusCode": status_code,
        "headers": headers,
        "body": json.dumps(body, default=json_default),
    }


def cors_headers(event):
    request_headers = event.get("headers") or {}
    request_origin = request_headers.get("origin") or request_headers.get("Origin")
    allow_origin = ALLOWED_ORIGINS[0] if ALLOWED_ORIGINS else "*"

    if "*" in ALLOWED_ORIGINS:
        allow_origin = "*"
    elif request_origin in ALLOWED_ORIGINS:
        allow_origin = request_origin

    return {
        "Access-Control-Allow-Origin": allow_origin,
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    }
def json_default(value):
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)

    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")
