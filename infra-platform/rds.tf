
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for RDS MySQL
resource "aws_security_group" "rds_mysql" {
  name        = "rds-mysql-sg"
  description = "Allow external MySQL access for Vault demo"
  vpc_id      = data.aws_vpc.default.id
}

# Allow MySQL from anywhere (0.0.0.0/0) - good for demos, not prod!
resource "aws_security_group_rule" "rds_mysql_ingress" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_mysql.id
}

resource "aws_db_instance" "demo" {
  identifier          = "demo-db-${module.rosa_hcp.cluster_id}"
  allocated_storage   = 20
  storage_type        = "gp2"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  username            = "vaultadmin"
  password            = random_password.rds.result
  skip_final_snapshot = true
  publicly_accessible = true  # allow OCP + Vault demo access
  vpc_security_group_ids = [aws_security_group.rds_mysql.id]
  backup_retention_period = 0 # disable backups for cheapest option
  tags = {
    Name = "demo-db-${module.rosa_hcp.cluster_id}"
  }
}

resource "random_password" "rds" {
  length  = 20
  special = true
}

output "rds_endpoint" {
  value = aws_db_instance.demo.address
}

output "rds_admin_username" {
  value = aws_db_instance.demo.username
}

output "rds_admin_password" {
  value     = random_password.rds.result
  sensitive = true
}