provider "aws" {
  region = var.aws_region
}


# Security Group for instances
resource "aws_security_group" "instance_sg" {
  name        = "instance_sg"
  description = "Allow SSH, HTTP, and all outbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change for more restricted access
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_sg.id] # Only allow traffic from the Load Balancer
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Allow HTTP access to Load Balancer"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to public for web access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template for Auto Scaling
resource "aws_launch_template" "app_template" {
  name_prefix   = "app-template"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "AppInstance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity     = 1
  min_size            = 1
  max_size            = 3
  vpc_zone_identifier = var.subnet_ids
  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "AppInstance"
    propagate_at_launch = true
  }
}

# CPU Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 60
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 60
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 60
  statistic         = "Average"
  threshold         = 70
  alarm_description  = "Scale up if CPU > 70% for 2 periods"
  alarm_actions      = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "low-cpu-utilization"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 60
  statistic         = "Average"
  threshold         = 30
  alarm_description  = "Scale down if CPU < 30% for 2 periods"
  alarm_actions      = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

# Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets           = var.subnet_ids
}

# Load Balancer Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

# Listener for Load Balancer
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Attach ASG to Target Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.app_asg.id
  lb_target_group_arn   = aws_lb_target_group.app_tg.arn
}
