output "load_balancer_dns" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.app_lb.dns_name
}

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app_asg.name
}

output "instance_security_group_id" {
  description = "The security group ID for instances"
  value       = aws_security_group.instance_sg.id
}

output "load_balancer_security_group_id" {
  description = "The security group ID for the Load Balancer"
  value       = aws_security_group.lb_sg.id
}
