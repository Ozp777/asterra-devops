output "wp_cluster_name" { value = aws_ecs_cluster.wp.name }
output "wp_service_name" { value = aws_ecs_service.wp.name }
output "wp_db_endpoint" { value = aws_db_instance.wp.address }
output "wp_logs_group" { value = aws_cloudwatch_log_group.wp.name }
output "wp_target_group_arn" { value = aws_lb_target_group.wp.arn }

