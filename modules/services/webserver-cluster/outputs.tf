output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "value of alb dns name"
}