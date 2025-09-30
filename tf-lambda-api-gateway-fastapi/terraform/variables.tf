variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "project" {
  type    = string
  default = "fastapi-http"
}

variable "lambda_name" {
  type    = string
  default = "fastapi-lambda"
}

variable "lambda_handler" {
  type    = string
  default = "app.main.handler" # module.file.function
}

variable "zip_path" {
  type        = string
  description = "Path to your local Lambda ZIP (e.g., ./function.zip)"
}
