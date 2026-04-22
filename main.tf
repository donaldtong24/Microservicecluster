provider "aws" {
    region = "us-east-1"
}

resource "aws_ecr_repository" "my_app" {
    name                = "my-python-service"
    image_tag_mutability = "MUTABLE"

    image_scanning_configuration{
        scan_on_push = true
    } 
}

output "repository_url" {
    value = aws_ecr_repository.my_app.repository_url
}