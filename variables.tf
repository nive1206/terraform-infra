variable "aws_profile" {
  type        = string
  description = "AWS profile to use"
  default     = "default"
}
variable "section_counter" {
  type        = any
  default     = { "section_3" = true }
  description = "Counter for sections it will trigger only module if it is true"
}

variable "repo_name" {
  type        = string
  default     = "crypto-app"
  description = "Name of the repository"
}

variable "repo_zip" {
  type        = string
  default     = "../microservices-project-main.zip"
  description = "Name of the zip file"
}