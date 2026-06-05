variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "key_name" {
  type    = string
  default = "ec2-k8s-key"
}

variable "instance_type" {
  type    = string
  default = "c7i-flex.large"
}

variable "my_ip" {
  type        = string
  description = "IP Public hiện tại của bạn kèm subnet mask /32"
}