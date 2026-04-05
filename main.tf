# =============================================================================
# LOCALS — derived values computed once and reused across all modules
# =============================================================================
locals {
  # Gateway IPs are always the first host in each subnet
  db_subnet_gateway       = cidrhost(var.db_subnet_cidr, 1)
  app_subnet_gateway      = cidrhost(var.app_subnet_cidr, 1)
  exposure_subnet_gateway = cidrhost(var.exposure_subnet_cidr, 1)

  # Common tags applied to every resource that supports them
  common_tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# =============================================================================
# NETWORKING
# =============================================================================

module "vpc" {
  source   = "./modules/vpc"
  vpc_name = "vpc"
  vpc_cidr = var.vpc_cidr
}

module "dbsubnet" {
  source             = "./modules/dbsubnet"
  subnet_name2       = "db-subnet"
  subnet_cidr2       = var.db_subnet_cidr
  subnet_gateway_ip2 = local.db_subnet_gateway
  vpc_id             = module.vpc.vpc_id
  availability_zone  = var.availability_zone
}

module "appsubnet" {
  source             = "./modules/appsubnet"
  subnet_name1       = "app-subnet"
  subnet_cidr1       = var.app_subnet_cidr
  subnet_gateway_ip1 = local.app_subnet_gateway
  vpc_id             = module.vpc.vpc_id
  availability_zone  = var.availability_zone
}

module "exposuresubnet" {
  source             = "./modules/exposuresubnet"
  subnet_name3       = "exposure-subnet"
  subnet_cidr3       = var.exposure_subnet_cidr
  subnet_gateway_ip3 = local.exposure_subnet_gateway
  vpc_id             = module.vpc.vpc_id
  availability_zone  = var.availability_zone
}

module "security-group" {
  source        = "./modules/security-group"
  secgroup_name = "secgroup-1"
}

# =============================================================================
# COMPUTE (ECS)
# =============================================================================

module "ecs1" {
  source       = "./modules/ecs/ecs-app-az1"
  ecs_name     = "ecs-app-az1"
  flavor       = var.ecs_flavor
  os           = var.ecs_image
  disk_type    = var.ecs_disk_type
  disk_size    = var.ecs_disk_size
  password     = var.ecs_password
  billing_mode = var.billing_mode
  secgroup_id  = module.security-group.security_group_id
  uuid         = module.appsubnet.subnet_id1
}

module "ecs2" {
  source       = "./modules/ecs/ecs-app-az2"
  ecs_name     = "ecs-app-az2"
  flavor       = var.ecs_flavor
  os           = var.ecs_image
  disk_type    = var.ecs_disk_type
  disk_size    = var.ecs_disk_size
  password     = var.ecs_password
  billing_mode = var.billing_mode
  secgroup_id  = module.security-group.security_group_id
  uuid         = module.appsubnet.subnet_id1
}

# =============================================================================
# STORAGE
# =============================================================================

module "obs" {
  source      = "./modules/obs"
  bucket_name = var.bucket_name
}

module "sfs_turbo" {
  source             = "./modules/sfs"
  name               = "sfs-turbo"
  size               = var.sfs_size
  share_type         = "STANDARD"
  availability_zone  = var.availability_zone
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.dbsubnet.subnet_id2
  security_group_id  = module.security-group.security_group_id
  tags               = local.common_tags
}

# =============================================================================
# DATABASE (RDS)
# =============================================================================

module "rds" {
  source                    = "./modules/rds/rds_instance"
  rds_name                  = "rds-primary"
  vpc_id                    = module.vpc.vpc_id
  subnet_id                 = module.dbsubnet.subnet_id2
  security_group_id         = module.security-group.security_group_id
  charging_mode             = var.billing_mode
  primary_availability_zone = var.availability_zone
  db_vcpus                  = var.db_vcpus
  db_memory                 = var.db_memory
  db_type                   = "MySQL"
  db_version                = var.db_version
  db_password               = var.rds_db_password
  db_port                   = var.db_port
  volume_size               = var.volume_size
  backup_start_time         = "02:00-03:00"
  backup_keep_days          = 7
  tags                      = local.common_tags
}

module "rds_read_replica" {
  source              = "./modules/rds/rds_read_replica"
  primary_instance_id = module.rds.rds_primary_id
  security_group_id   = module.security-group.security_group_id
  availability_zone   = var.replica_availability_zone
  name                = "rds-read-replica"
  flavor              = "rds.mysql.x1.xlarge.2"
  db_port             = var.db_port
}

module "dcs_master_standby" {
  source    = "./modules/dcs"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.dbsubnet.subnet_id2
}

# =============================================================================
# CCE (Kubernetes Cluster + Worker Node)
# =============================================================================

module "cce" {
  source                 = "./modules/cce"
  cluster_name           = "master"
  flavor                 = "cce.s1.small"
  billing_mode           = var.billing_mode
  container_network_type = "vpc-router"
  vpc_id                 = module.vpc.vpc_id
  subnet_id              = module.appsubnet.subnet_id1
}

module "cce_nodes" {
  source       = "./modules/cce_nodes"
  node_name    = "worker1"
  flavor       = "s6.large.2"
  billing_mode = var.billing_mode
  admin_pass   = var.cce_node_password
  cluster_id   = module.cce.cce_id
}

# =============================================================================
# EXPOSURE SUBNET — Load Balancer + NAT Gateway
# =============================================================================

module "elb" {
  source            = "./modules/elb"
  elb_name          = "elb-exposure"
  lb_method         = "ROUND_ROBIN"
  bandwidth_size    = var.bandwidth_size
  availability_zone = var.availability_zone
  vpc_id            = module.vpc.vpc_id
  ipv4_subnet_id    = module.exposuresubnet.subnet_ipv4_subnet_id3
  backend_subnet_id = module.appsubnet.subnet_ipv4_subnet_id1
  backend_ips       = [module.ecs1.private_ip, module.ecs2.private_ip]
  tags              = local.common_tags
}

module "nat_gateway" {
  source         = "./modules/nat_gateway"
  nat_name       = "nat-gateway"
  spec           = "1"
  bandwidth_size = var.bandwidth_size
  vpc_id         = module.vpc.vpc_id
  subnet_id      = module.exposuresubnet.subnet_id3
  app_subnet_id  = module.appsubnet.subnet_id1
  tags           = local.common_tags
}

# =============================================================================
# DNS
# =============================================================================

module "dns" {
  source           = "./modules/dns"
  zone_name        = var.domain_name
  zone_type        = "private"
  region           = var.region
  ttl              = 300
  vpc_id           = module.vpc.vpc_id
  elb_eip_address  = module.elb.elb_vip_address
  depends_on       = [module.elb]
}

# =============================================================================
# LOGGING (LTS)
# =============================================================================

module "lts" {
  source               = "./modules/lts"
  log_group_name       = "lts-log-group"
  log_group_ttl_in_days = 30
  log_stream_name      = "lts-log-stream"
  tags                 = local.common_tags
}

# =============================================================================
# MONITORING — CloudEye (ECS CPU alarm) + AOM (node CPU alarm)
# =============================================================================

module "cloudeye" {
  source               = "./modules/cloudeye"
  alarm_name           = "cpu-high-ecs1"
  alarm_description    = "CPU utilization is over 80%"
  alarm_enabled        = true
  alarm_smn_urn        = var.alarm_email
  namespace            = "SYS.ECS"
  metric_name          = "cpu_util"
  dimension_name       = "instance_id"
  dimension_value      = module.ecs1.instance_id
  period               = 300   # seconds: 1 | 300 | 1200 | 3600 | 14400 | 86400
  filter               = "average"
  comparison_operator  = ">="
  value                = 80
  unit                 = "%"
  evaluation_periods   = 1
}

module "aom" {
  source                   = "./modules/aom"
  alarm_rule_name          = "aom-cpu-alarm"
  alarm_rule_description   = "AOM alarm for node CPU usage"
  alarm_rule_enable        = true
  alarm_rule_level         = 2   # 2 = Major
  metric_namespace         = "PAAS.NODE"
  metric_name              = "cpuUsage"
  metric_unit              = "%"
  metric_dimensions        = []  # empty = module uses default hostID
  period                   = 60000
  statistic                = "average"
  comparison_operator      = ">="
  threshold                = 80
  evaluation_periods       = 3
  alarm_smn_urn            = var.alarm_email
  tags                     = local.common_tags
  depends_on               = [module.lts]
}

# =============================================================================
# WAF (disabled — uncomment when a domain certificate is ready)
# =============================================================================
# module "waf" {
#   source          = "./modules/waf"
#   domain          = var.domain_name
#   proxy           = false
#   backend_address = module.elb.elb_vip_address
#   backend_port    = 80
# }
