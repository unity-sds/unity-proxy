# tflint-ignore: terraform_unused_declarations
variable "tags" {
  description = "AWS Tags"
  type        = map(string)
}

# tflint-ignore: terraform_unused_declarations
variable "deployment_name" {
  description = "The deployment name"
  type        = string
}

variable "mgmt_dns" {
  description = "The DNS or IP of the ALB or EC2 instance"
  type        = string
}

variable "project" {
  description = "The unity project its installed into"
  type        = string
  default     = "UnknownProject"
}

variable "venue" {
  description = "The unity venue its installed into"
  type        = string
  default     = "UnknownVenue"
}

# tflint-ignore: terraform_unused_declarations
variable "installprefix" {
  description = "The management console install prefix"
  type        = string
  default     = "UnknownPrefix"
}

variable "httpd_proxy_version" {
  description = "The version of the httpd proxy container"
  type        = string
  default     = "0.16.0"
}
