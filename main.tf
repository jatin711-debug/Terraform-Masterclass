terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}

variable "server_port" {
  description = "value of port server will listen on"
  default     = "8080"
  type        = number
}

# resource "aws_instance" "running_server" {
#   ami                    = "ami-0ea18256de20ecdfc"
#   instance_type          = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.server_security_group.id]
#   user_data              = <<-EOF
#               #!/bin/bash
#               sudo apt install -y apache2
#               sudo apt-get install ec2-instance-connect 
#               yum install -y httpd
#               echo "Hello, World" > index.html
#               nohup busybox httpd -f -p ${var.server_port} &
#               EOF
#   tags = {
#     Name = "terraform-example"
#   }
# }

resource "aws_security_group" "server_security_group" {
  name        = "terraform-example"
  description = "Allow HTTP and SSH inbound traffic"
  ingress {
    description = "HTTP from VPC"
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


# output "public_ip" {
#   value       = aws_instance.running_server.public_ip
#   description = "value of public ip of the server"
# }


resource "aws_launch_configuration" "example" {
  name           = "terraform-example"
  image_id        = "ami-0ea18256de20ecdfc"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.server_security_group.id]
  lifecycle {
    create_before_destroy = true
  }
  user_data       = <<-EOF
              #!/bin/bash
              sudo apt install -y apache2
              sudo apt-get install ec2-instance-connect 
              yum install -y httpd
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
}


# get the details of default vpc

data "aws_vpc" "default" {
  default = true
}
#use default vpc id and get default subnet ids
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# data "aws_subnet" "example" {
#   for_each = toset(data.aws_subnets.default.ids)
#   id       = each.value
# }

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  # use default subnet ids
  vpc_zone_identifier  = data.aws_subnets.default.ids
  target_group_arns    = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 3

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}


resource "aws_lb" "example" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default.ids
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Page Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_security_group" "alb" {
  name = "terraform-example-alb"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "asg" {
  name ="terraform-asg-target-group"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id
  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 1

  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "Domain name of the load balancer"
}