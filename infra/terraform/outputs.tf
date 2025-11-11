output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_ids" {
  value = [aws_subnet.private1.id, aws_subnet.private2.id]
}

output "rds_endpoint" {
  value = aws_db_instance.pg.address
}

output "rds_port" {
  value = aws_db_instance.pg.port
}
