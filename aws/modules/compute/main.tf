data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "k8s_node" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  root_block_device {
    volume_size           = 15
    volume_type           = "gp3"
    delete_on_termination = true
  }
  subnet_id              = var.public_subnet_1_id
  vpc_security_group_ids = [var.ec2_sg_id]
  key_name               = var.key_name
  credit_specification {
    cpu_credits = "standard"
  }
  user_data = file("${path.root}/scripts/install-minikube.sh")
  tags = {

    Name = "k8s-minkube-host"

  }

}



resource "aws_lb" "web_alb" {

  name = "real-web-alb"

  internal = false

  load_balancer_type = "application"

  security_groups = [var.alb_sg_id]

  subnets = [var.public_subnet_1_id, var.public_subnet_2_id]

}



resource "aws_lb_target_group" "tg" {

  name = "real-k8s-tg"

  port = 30080

  protocol = "HTTP"

  vpc_id = var.vpc_id

  target_type = "instance"



  health_check {

    path = "/"

    port = "30080"

  }

}



resource "aws_lb_target_group_attachment" "tg_attachment" {

  target_group_arn = aws_lb_target_group.tg.arn

  target_id = aws_instance.k8s_node.id

  port = 30080

}



resource "aws_lb_listener" "front_end" {

  load_balancer_arn = aws_lb.web_alb.arn

  port = 80

  protocol = "HTTP"



  default_action {

    type = "forward"

    target_group_arn = aws_lb_target_group.tg.arn

  }

}