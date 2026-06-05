output "ec2_public_ip" {
  description = "Public IP of the Minikube EC2 Instance"
  value       = module.compute.ec2_public_ip
}

output "alb_dns_name" {
  description = "DNS Name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}