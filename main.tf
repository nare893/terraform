# VPC Creation
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "tvpc"
  }
}

# Subnet Creation
resource "aws_subnet" "my_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "tsubnet"
  }
}
# Subnet Creation in AZ 2
resource "aws_subnet" "my_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.0.128/25"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "tsubnet-2"
  }
}
# Internet Gateway Creation
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-igw"
  }
}


# Security Group Creation
resource "aws_security_group" "my_sg" {
  vpc_id = aws_vpc.my_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tsg"
  }
}

# Launch Configuration for Auto Scaling Group
resource "aws_launch_configuration" "task" {
  name                        = "my-launch-config"
  image_id                    = "ami-0d473344347276854"
  instance_type               = "t2.micro"
  security_groups             = [aws_security_group.my_sg.id]
  associate_public_ip_address = true
}

# Auto Scaling Group
resource "aws_autoscaling_group" "my_asg" {
  launch_configuration = aws_launch_configuration.task.id
  min_size             = 1
  max_size             = 2
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.my_subnet_1.id, aws_subnet.my_subnet_2.id]
  tag {
    key                 = "Name"
    value               = "my-asg-instance"
    propagate_at_launch = true
  }
}

# Load Balancer
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_sg.id]
  subnets            = [aws_subnet.my_subnet_1.id, aws_subnet.my_subnet_2.id]

  enable_deletion_protection = false
  idle_timeout               = 60

  tags = {
    Name = "my-alb"
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Hello from Terraform!"
      status_code  = "200"
    }
  }
}

# Target Group
resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    interval            = 30
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Attach Auto Scaling Group to Load Balancer
resource "aws_autoscaling_attachment" "my_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.my_asg.name
  lb_target_group_arn    = aws_lb_target_group.my_target_group.arn
}

