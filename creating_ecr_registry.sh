#!/bin/bash

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Prompt user for repository name and region
read -p "Enter the repository name: " REPOSITORY_NAME
read -p "Enter the AWS region: " REGION

# Validate inputs
if [[ -z "$REPOSITORY_NAME" ]]; then
    handle_error "Repository name cannot be empty."
fi

if [[ -z "$REGION" ]]; then
    handle_error "Region cannot be empty."
fi

# Create ECR repository
echo "Creating ECR repository '$REPOSITORY_NAME' in region '$REGION'..."
CREATE_OUTPUT=$(aws ecr create-repository --repository-name "$REPOSITORY_NAME" --region "$REGION" 2>&1)

if [[ $? -ne 0 ]]; then
    handle_error "Failed to create repository. AWS CLI output: $CREATE_OUTPUT"
fi

# Output the repository URI
REPOSITORY_URI=$(aws ecr describe-repositories --repository-names "$REPOSITORY_NAME" --region "$REGION" --query 'repositories[0].repositoryUri' --output text 2>&1)

if [[ $? -ne 0 ]]; then
    handle_error "Failed to describe repository. AWS CLI output: $REPOSITORY_URI"
fi

echo "Repository URI: $REPOSITORY_URI"
