# =============================================================================
# HUAWEI CLOUD CREDENTIALS
# =============================================================================
variable "access_key" {
  description = "Huawei Cloud access key."
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Huawei Cloud secret key."
  type        = string
  sensitive   = true
}

# =============================================================================
# GENERAL
# =============================================================================
variable "region" {
  description = "Huawei Cloud region."
  type        = string
  default     = "sa-brazil-1"
}

variable "availability_zone" {
  description = "Primary availability zone."
  type        = string
  default     = "sa-brazil-1a"
}

variable "environment" {
  description = "Environment label applied to all resource tags."
  type        = string
  default     = "training"
}

# =============================================================================
# NETWORKING
# =============================================================================
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "192.168.0.0/16"
}

variable "db_subnet_cidr" {
  description = "CIDR block for the database subnet."
  type        = string
  default     = "192.168.1.0/24"
}

variable "app_subnet_cidr" {
  description = "CIDR block for the application subnet."
  type        = string
  default     = "192.168.2.0/24"
}

variable "exposure_subnet_cidr" {
  description = "CIDR block for the exposure (public-facing) subnet."
  type        = string
  default     = "192.168.3.0/24"
}

# =============================================================================
# COMPUTE (ECS)
# =============================================================================
variable "ecs_flavor" {
  description = "Flavor (instance type) for ECS instances."
  type        = string
  default     = "t6.small.1"
}

variable "ecs_image" {
  description = "OS image for ECS instances."
  type        = string
  default     = "Ubuntu 22.04 server 64bit"
}

variable "ecs_disk_type" {
  description = "System disk type for ECS instances."
  type        = string
  default     = "SAS"
}

variable "ecs_disk_size" {
  description = "System disk size in GB for ECS instances."
  type        = number
  default     = 40
}

variable "ecs_password" {
  description = "Admin password for ECS instances."
  type        = string
  sensitive   = true
}

variable "billing_mode" {
  description = "Billing mode for resources (postPaid or prePaid)."
  type        = string
  default     = "postPaid"
}

# =============================================================================
# DATABASE (RDS)
# =============================================================================
variable "rds_db_password" {
  description = "Master password for the RDS instance."
  type        = string
  sensitive   = true
}

variable "db_vcpus" {
  description = "Number of vCPUs for the RDS instance."
  type        = number
  default     = 2
}

variable "db_memory" {
  description = "Memory in GB for the RDS instance."
  type        = number
  default     = 4
}

variable "db_version" {
  description = "MySQL version for the RDS instance."
  type        = string
  default     = "8.0"
}

variable "db_port" {
  description = "Port for the RDS database."
  type        = number
  default     = 3306
}

variable "volume_size" {
  description = "Storage volume size in GB for the RDS instance."
  type        = number
  default     = 40
}

# =============================================================================
# STORAGE
# =============================================================================
variable "bucket_name" {
  description = "Name of the OBS (object storage) bucket."
  type        = string
}

variable "sfs_size" {
  description = "Size in GB for the SFS Turbo shared file system."
  type        = number
  default     = 500
}

# =============================================================================
# CCE (Kubernetes)
# =============================================================================
variable "cce_node_password" {
  description = "Admin password for CCE worker nodes."
  type        = string
  sensitive   = true
}

# =============================================================================
# LOAD BALANCER + NAT
# =============================================================================
variable "bandwidth_size" {
  description = "EIP bandwidth in Mbit/s for the ELB and NAT Gateway."
  type        = number
  default     = 10
}

# =============================================================================
# DNS
# =============================================================================
variable "domain_name" {
  description = "Private DNS zone name (must end with a dot, e.g. 'app.internal.')."
  type        = string
}

# =============================================================================
# MONITORING
# =============================================================================
variable "alarm_email" {
  description = "SMN topic URN for alarm notifications. Leave empty to disable."
  type        = string
  default     = ""
}

variable "replica_availability_zone" {
  description = "Availability zone for the RDS read replica."
  type        = string
  default     = "sa-brazil-1b"
}
