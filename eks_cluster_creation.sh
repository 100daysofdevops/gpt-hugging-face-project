#!/bin/bash

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Function to check if aws cli is installed
check_aws_cli_installed() {
    if ! command -v aws &> /dev/null; then
        handle_error "AWS CLI is not installed. Please install it and try again."
    fi
}

# Check if AWS CLI is installed
check_aws_cli_installed

# Get the AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [[ -z "$ACCOUNT_ID" ]]; then
    handle_error "Failed to get AWS account ID."
fi
echo "AWS Account ID: $ACCOUNT_ID"

# Prompt user for cluster name and region
read -p "Enter the cluster name: " CLUSTER_NAME
read -p "Enter the AWS region: " REGION
read -p "Enter the Kubernetes version (e.g., 1.23): " K8S_VERSION

# Validate inputs
if [[ -z "$CLUSTER_NAME" ]]; then
    handle_error "Cluster name cannot be empty."
fi

if [[ -z "$REGION" ]]; then
    handle_error "Region cannot be empty."
fi

if [[ -z "$K8S_VERSION" ]]; then
    handle_error "Kubernetes version cannot be empty."
fi

# Create IAM role for EKS Cluster
cat <<EoF > eks-cluster-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EoF

aws iam create-role --role-name eks-cluster-role --assume-role-policy-document file://eks-cluster-trust-policy.json
aws iam attach-role-policy --role-name eks-cluster-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
if [[ $? -ne 0 ]]; then
    handle_error "Failed to create IAM role for EKS Cluster."
fi
echo "IAM role for EKS Cluster created successfully."

# Create IAM role for EKS Node Group
cat <<EoF > eks-node-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EoF

aws iam create-role --role-name eks-node-instance-role --assume-role-policy-document file://eks-node-trust-policy.json
aws iam attach-role-policy --role-name eks-node-instance-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name eks-node-instance-role --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name eks-node-instance-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
if [[ $? -ne 0 ]]; then
    handle_error "Failed to create IAM role for EKS Node Group."
fi
echo "IAM role for EKS Node Group created successfully."

# Get the default VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $REGION)
if [[ -z "$VPC_ID" ]]; then
    handle_error "Failed to get the default VPC ID."
fi
echo "Default VPC ID: $VPC_ID"

# Get the default subnets
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text --region $REGION)
if [[ -z "$SUBNET_IDS" ]]; then
    handle_error "Failed to get the default subnets."
fi

# Convert space-separated subnet IDs to comma-separated list
SUBNET_IDS=$(echo $SUBNET_IDS | tr ' ' ',')
echo "Default Subnet IDs: $SUBNET_IDS"

# Create EKS Cluster
aws eks create-cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --kubernetes-version $K8S_VERSION \
  --role-arn arn:aws:iam::$ACCOUNT_ID:role/eks-cluster-role \
  --resources-vpc-config subnetIds=$SUBNET_IDS \
  --output text
if [[ $? -ne 0 ]]; then
    handle_error "Failed to create EKS Cluster."
fi
echo "EKS Cluster '$CLUSTER_NAME' created successfully."

# Wait for the EKS cluster to become active
aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION
if [[ $? -ne 0 ]]; then
    handle_error "EKS Cluster '$CLUSTER_NAME' failed to become active."
fi
echo "EKS Cluster '$CLUSTER_NAME' is now active."

# Create Node Group
aws eks create-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name "${CLUSTER_NAME}-nodegroup" \
  --subnets $SUBNET_IDS \
  --node-role arn:aws:iam::$ACCOUNT_ID:role/eks-node-instance-role \
  --scaling-config minSize=1,maxSize=2,desiredSize=1 \
  --instance-types t3.medium \
  --region $REGION \
  --output text
if [[ $? -ne 0 ]]; then
    handle_error "Failed to create Node Group."
fi
echo "Node Group '${CLUSTER_NAME}-nodegroup' created successfully."

# Wait for the node group to become active
aws eks wait nodegroup-active --cluster-name $CLUSTER_NAME --nodegroup-name "${CLUSTER_NAME}-nodegroup" --region $REGION
if [[ $? -ne 0 ]]; then
    handle_error "Node Group '${CLUSTER_NAME}-nodegroup' failed to become active."
fi
echo "Node Group '${CLUSTER_NAME}-nodegroup' is now active."

# Clean up
rm eks-cluster-trust-policy.json
rm eks-node-trust-policy.json

echo "EKS cluster and node group setup completed successfully."
