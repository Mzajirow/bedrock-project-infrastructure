resource "aws_db_subnet_group" "main" {
  name       = "project-bedrock-db-subnets"
  subnet_ids = module.vpc.private_subnets
  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_security_group" "rds" {
  name   = "project-bedrock-rds-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
  tags = { Project = "karatu-2025-capstone" }
}

resource "random_password" "mysql" {
  length  = 16
  special = false
}

resource "aws_db_instance" "mysql" {
  identifier = "bedrock-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name    = "catalog"
  username          = "admin"
  password          = random_password.mysql.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  tags = { Project = "karatu-2025-capstone" }
}

resource "random_password" "postgres" {
  length  = 16
  special = false
}

resource "aws_db_instance" "postgres" {
  identifier = "bedrock-postgres"
  engine            = "postgres"
  engine_version    = "16.3"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name    = "orders"
  username          = "dbadmin"
  password          = random_password.postgres.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_secretsmanager_secret" "postgres_creds" {
  name = "project-bedrock/postgres"
  recovery_window_in_days = 0
  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_secretsmanager_secret_version" "postgres_creds" {
  secret_id     = aws_secretsmanager_secret.postgres_creds.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.postgres.result
    host     = aws_db_instance.postgres.address
  })
}

resource "aws_secretsmanager_secret" "mysql_creds" {
  name                    = "project-bedrock/mysql"
  recovery_window_in_days = 0
  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_secretsmanager_secret_version" "mysql_creds" {
  secret_id     = aws_secretsmanager_secret.mysql_creds.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.mysql.result
    host     = aws_db_instance.mysql.address
  })
}