# FastAPI on AWS Lambda + API Gateway (HTTP API)

This guide shows two ways to deploy a FastAPI app (via **Mangum**) on AWS Lambda behind an **API Gateway HTTP API**:

1. **AWS Console (click-through)**
2. **Terraform** (with a helper script `terraform_manage.sh`)

---

## Prerequisites

* An AWS account with permissions to manage **Lambda**, **API Gateway**, **IAM**, and **CloudWatch Logs**
* A packaged Lambda **ZIP file** that contains your code and dependencies at the ZIP root

  * Example handler: `app.main.handler`
  * Example content layout inside `function.zip`:

    ```
    app/
      __init__.py
      main.py   # defines: handler = Mangum(app)
    fastapi/  mangum/  starlette/  ... (deps)
    ```
* (Optional) **AWS CLI** v2 installed and configured
* (Optional) **Terraform** v1.5+ if you’ll use the IaC flow

> 🧩 If you build on macOS and use packages with native wheels (e.g., pydantic-core), either build the ZIP on Linux or pin to pure-Python deps.

---

## Part A — Deploy via AWS Console (HTTP API)

### 1) Create the Lambda function

1. Console → **Lambda** → **Create function** → *Author from scratch*

   * **Name:** `fastapi-lambda`
   * **Runtime:** `Python 3.12`
   * **Architecture:** `x86_64`
   * **Permissions:** Create a new role with basic Lambda permissions
   * Click **Create function**
2. **Upload code**: Function page → **Code** tab → **Upload from** → **.zip file** → choose `function.zip` → **Save**
3. **Handler**: **Runtime settings** → **Edit** → set **`app.main.handler`** → **Save**
4. (Optional) **Timeout**: **Configuration** → **General configuration** → **Edit** → set to **10 seconds** → **Save**
5. **Quick test**: **Test** → **Configure test event** → *Template:* **API Gateway AWS Proxy** → use minimal body:

   ```json
   {
     "resource": "/",
     "path": "/",
     "httpMethod": "GET",
     "queryStringParameters": null,
     "headers": {},
     "requestContext": {},
     "body": null,
     "isBase64Encoded": false
   }
   ```

   **Save** → **Test** → expect 200 and your root JSON response.

### 2) Create/Configure the HTTP API

> HTTP API uses **Routes** and **Integrations** (no “Actions” menu like REST API).

1. Console → **API Gateway** → **HTTP APIs** → select your API (or create one)
2. **Integrations** → **Add integration** → **Lambda** → choose `fastapi-lambda` → **Add**
3. **Routes** → **Create** → **Route key:** `$default` → **Integration:** `fastapi-lambda` → **Create**

   * If `$default` already exists, open it and ensure the **Integration** is your Lambda (attach if missing)
4. **Stages** → select your stage (often **$default**) → ensure **Auto-deploy** is **ON** (if OFF, click **Deploy**)

### 3) Test the API

* For a `$default` stage (no suffix in URL):

  ```bash
  curl -i https://<api-id>.execute-api.<region>.amazonaws.com/
  curl -i https://<api-id>.execute-api.<region>.amazonaws.com/api/v1/users
  ```

### (Optional) Explicit greedy proxy route

If you prefer seeing a visible path:

* **Routes** → **Create** → **Method:** `ANY` → **Path:** `/{proxy+}` → **Create**
* Select the new route → **Attach integration** → `fastapi-lambda` → **Attach**
* **Stages** → Auto‑deploy ON (or **Deploy**)

### (Optional) CORS for browsers

* In the HTTP API → **CORS** → set **Allow origins** (e.g., `*` for testing), **Allow methods** (GET, POST, etc.) → **Save** (deploy if auto‑deploy is off)

---

## Part B — Deploy via Terraform (HTTP API v2)

This section assumes the following Terraform files in an `infra/` directory:

```
infra/
  main.tf           # resources for Lambda + HTTP API
  variables.tf      # variable definitions
  terraform.tfvars  # optional shared defaults
  env/
    dev.tfvars      # per-workspace overrides (e.g., zip_path)
    prod.tfvars
  terraform_manage.sh
function.zip         # or keep elsewhere and point via zip_path
```

### Example `variables.tf`

```hcl
variable "region"        { type = string, default = "us-east-1" }
variable "project"       { type = string, default = "fastapi-http" }
variable "lambda_name"   { type = string, default = "fastapi-lambda" }
variable "lambda_handler"{ type = string, default = "app.main.handler" }
variable "zip_path"      { type = string, description = "Path to your local Lambda ZIP" }
```

### Example `main.tf` (essentials)

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" { region = var.region }

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["lambda.amazonaws.com"] }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "fn" {
  function_name = var.lambda_name
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = var.lambda_handler
  filename         = var.zip_path
  source_code_hash = filebase64sha256(var.zip_path)
  architectures = ["x86_64"]
  timeout       = 10
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.fn.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowInvokeFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

output "invoke_url" {
  value       = aws_apigatewayv2_stage.stage.invoke_url
  description = "Base URL of the HTTP API stage"
}
```

### Example `env/dev.tfvars`

```hcl
region         = "us-east-1"
project        = "fastapi-http"
lambda_name    = "fastapi-lambda"
lambda_handler = "app.main.handler"
zip_path       = "../function.zip"  # adjust to your ZIP path
```

---

## Part C — Terraform helper script (`terraform_manage.sh`)

Place this script in the `infra/` folder. It:

* selects/creates a **workspace** (default `dev`)
* uses `env/<workspace>.tfvars` if present
* verifies your **ZIP** exists
* runs `init`, `fmt`, `validate`, `plan`, `apply` (or `destroy`)
* prints the **invoke URL** after apply

### Usage

```bash
cd infra
chmod +x terraform_manage.sh

# defaults to: dev apply
./terraform_manage.sh

# explicit
./terraform_manage.sh dev apply
./terraform_manage.sh prod apply
./terraform_manage.sh dev destroy
```

### Optional pre-build hook

If you want the script to build your ZIP before apply:

```bash
export PRE_BUILD="../build_zip.sh"   # path to your local build script
./terraform_manage.sh
```

> The script reads `zip_path` from `TF_VAR_zip_path`, `env/<ws>.tfvars`, or `terraform.tfvars`. Ensure it points to your `function.zip`.

---

## Testing

After a successful Console or Terraform deploy:

```bash
# HTTP API with $default stage (no suffix)
curl -i https://<api-id>.execute-api.<region>.amazonaws.com/
curl -i https://<api-id>.execute-api.<region>.amazonaws.com/api/v1/users
```

---
## Screenshot of Deployment

<img width="828" height="827" alt="Lab-4-Lambda-API-Gateway" src="https://github.com/user-attachments/assets/fd8816b9-a2d6-4466-bd1d-707c88abf92d" />
<img width="1608" height="897" alt="Lab-4-Lambda-API-Gateway-Terraform" src="https://github.com/user-attachments/assets/c07da9d4-b76b-4411-a32c-425e7844df24" />

---

## Troubleshooting

* **ImportModuleError (e.g., pydantic_core)**: Package on Linux (Amazon Linux container/host) or stick to pure-Python deps.
* **404 "Not Found"**: API is reaching Lambda; your app route doesn’t match. Call exact path (slash sensitivity) or register both `/users` and `/users/`.
* **HTTP API deploy error "no valid routes"**: Add a route (`$default` or `ANY /{proxy+}`) and attach the Lambda integration.
* **Wrong URL**: `$default` stage has **no suffix**; a named stage like `dev` requires `/dev`.
* **CORS**: Configure CORS in the **HTTP API** console (Allow origins/methods) for browser calls.
