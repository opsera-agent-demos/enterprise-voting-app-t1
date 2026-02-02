variable "app_name" {
  type    = string
  default = "sperivote11"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "tenant" {
  type    = string
  default = "opsera"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "elasticache_node_type" {
  type    = string
  default = "cache.t3.micro"
}
