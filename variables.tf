variable "env" {
  default = "Test"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = [
    "10.0.1.0/24"
  ]
}

variable "name" {
  default = "Test"
}

variable "instance_type" {
  default = "t2.small"
}
variable "message" {
  default = "HelloWorld"
}


variable "tags" {
  default = {
    Owner   = "Ashutosh"
    Project = "POC"
  }
}
