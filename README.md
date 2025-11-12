# 🌍 Asterra – Public Service Deployment (WordPress on ECS)

## 🧩 Overview
This module deploys the **public-facing service** for the Asterra project, based on **WordPress running on ECS Fargate**.
It connects to an existing **RDS MySQL instance**, uses **EFS** for persistent storage, and is served via a **public ALB**.

## ✅ Current Stack
- **ECS Fargate** – WordPress container (`wordpress:6.6-php8.2-apache`)
- **RDS MySQL** – managed database for WordPress
- **EFS** – persistent storage for `/wp-content`
- **ALB (Application Load Balancer)** – public endpoint for HTTP access
- **Terraform IaC** – all infrastructure is managed as code

## 🧾 Deployment Steps
1. Run Terraform:
   ```bash
   terraform init -upgrade
   terraform validate
   terraform plan
   terraform apply


Wait for ECS service to reach a steady state.

Access WordPress installation screen:

👉 http://asterra-demo-alb-1269054896.us-east-1.elb.amazonaws.com/wp

Complete the setup wizard (site title, username, password, email).

🛠 Notes

No domain / Route 53 / ACM is required (public ALB DNS is used directly).

Service is configured for Fargate with assign_public_ip = true for simplicity.

Security groups restrict traffic appropriately between ECS, RDS, and EFS.

📦 Outputs

After terraform apply, you can check key details:

terraform output


You’ll get ECS cluster/service names, RDS endpoint, EFS ID, and Target Group ARN.

🟢 Status: Project fully deployed and functional – ready for demonstration or further expansion (HTTPS, scaling, CI/CD if desired).
