output "final_web_url" {
  value       = "http://${data.terraform_remote_state.aws_infra.outputs.alb_dns_name}"
  description = "Địa chỉ đường dẫn URL truy cập vào ứng dụng thông qua AWS ALB"
}