# Azure Private Infrastructure

This repository contains Terraform Infrastructure as Code (IaC) for deploying private Azure infrastructure.


# Getting Started

Clone the repository:
   
   git clone https://github.com/chaitanya630177/azure-private-infra.git

   cd azure-private-infra/terraform

Intilaize Terraform
terraform init

For Validation:
terraform validate

Plan the infrastructure:
terraform plan

Apply the configuration:
terraform apply -auto-approve

CI/CD

The Azure DevOps pipeline (azure-pipeline.yml) runs Terraform commands automatically for validation and deployment.
