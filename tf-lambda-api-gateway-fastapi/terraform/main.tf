terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {
  region = var.region
}

# --- IAM role for Lambda ---
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Basic execution policy (writes logs to CloudWatch)
resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Lambda function (uses your local ZIP) ---
resource "aws_lambda_function" "fn" {
  function_name = var.lambda_name
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = var.lambda_handler

  # Path to your local zip (relative to this Terraform folder or absolute)
  filename         = var.zip_path
  source_code_hash = filebase64sha256(var.zip_path) # forces update on zip changes

  architectures = ["x86_64"]
  timeout       = 10
}

# --- HTTP API (API Gateway v2) ---
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project}-http-api"
  protocol_type = "HTTP"
}

# Integration: HTTP API -> Lambda (proxy)
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.fn.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Route: catch-all ($default) to the Lambda integration
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage with auto-deploy so changes go live automatically
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

# Permission: allow API Gateway to invoke your Lambda
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowInvokeFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# ---- (Optional) CORS for browsers ----
# resource "aws_apigatewayv2_api" "http" {
#   name          = "${var.project}-http-api"
#   protocol_type = "HTTP"
#   cors_configuration {
#     allow_origins = ["*"]
#     allow_methods = ["GET","POST","PUT","DELETE","OPTIONS"]
#     allow_headers = ["*"]
#   }
# }

output "invoke_url" {
  value       = aws_apigatewayv2_stage.stage.invoke_url
  description = "Base URL of the HTTP API stage"
}
