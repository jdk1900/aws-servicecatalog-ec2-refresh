# AWS DevOps Agent Refresh Pipeline
# Overview
This repository provides an automated pipeline for provisioning and updating AWS Service Catalog products that host Azure DevOps agents running on EC2 instances within an Auto Scaling Group (ASG). The solution ensures instances are seamlessly updated with the latest version of the product, using AWS instance refresh for controlled restarts.

# How It Works
The pipeline detects if a specific product is provisioned, if not then the it provisions the product.
The product's name is defined as a variable in Azure Devops Library.
If the product exists then the code checks if a new version of the AWS Service Catalog product is available.
If a new version exists, it provisions the updated product.
EC2 instances within the Auto Scaling Group are refreshed one by one, ensuring minimal disruption.
Configurable warm-up times ensure instances are fully initialized before replacements continue.
The pipeline can be scheduled to run every day at a specific time via "Triggers" in Azure Devops or by using cron.

# Environments
The pipeline currently supports deployments to multiple environments:

Test (TST)

Acceptance (ACC)

Production (PRD)

Environment-specific values such as AWS account IDs, ASG prefixes, and tags are managed via Azure DevOps Library.

# Prerequisites
AWS Service Catalog configured for your product.
Azure DevOps Pipeline setup.
Access to required AWS IAM roles and permissions.
Bash support for automation scripts.

# Key Files
pipeline.yaml: Main Azure DevOps pipeline configuration.
provision_product.sh: Bash script for provisioning and updating AWS Service Catalog products.
parameters.json: JSON file containing product-specific parameters.
deploy-service-catalog.yml: Template used for stage-specific deployments.

# Getting Started
Clone the repository.
Configure your environment variables in the Azure DevOps Library.
Run the pipeline to provision or update the product.

# Technologies Used
AWS Service Catalog

AWS Auto Scaling Groups (ASG)

Azure DevOps Pipelines

Bash Scripting

AWS CLI
