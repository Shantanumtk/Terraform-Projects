output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.web_bucket.id
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.rds_instance.endpoint
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.rds_instance.port
}
