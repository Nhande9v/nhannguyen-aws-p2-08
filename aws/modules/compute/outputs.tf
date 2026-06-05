output "ec2_public_ip" {
  value = aws_instance.k8s_node.public_ip
}

output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}