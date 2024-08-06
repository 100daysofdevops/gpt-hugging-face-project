#!/bin/bash

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Function to check if gh cli is installed
check_gh_cli_installed() {
    if ! command -v gh &> /dev/null; then
        echo "GitHub CLI is not installed. Installing GitHub CLI..."
        install_gh_cli
    else
        echo "GitHub CLI is already installed."
    fi
}

# Function to install gh cli
install_gh_cli() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Install on Linux
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
        sudo apt-add-repository https://cli.github.com/packages
        sudo apt update
        sudo apt install gh
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Install on macOS
        brew install gh
    else
        handle_error "Unsupported OS type: $OSTYPE. Please install GitHub CLI manually."
    fi

    if ! command -v gh &> /dev/null; then
        handle_error "Failed to install GitHub CLI."
    fi
}

# Function to authenticate gh cli
authenticate_gh_cli() {
    if ! gh auth status &> /dev/null; then
        echo "GitHub CLI is not authenticated. Please authenticate."
        gh auth login
        if [[ $? -ne 0 ]]; then
            handle_error "Failed to authenticate GitHub CLI."
        fi
    else
        echo "GitHub CLI is already authenticated."
    fi
}

# Check if GitHub CLI is installed
check_gh_cli_installed

# Authenticate GitHub CLI
authenticate_gh_cli

# Prompt user for GitHub repository, secret name, and secret value
read -p "Enter the GitHub repository (e.g., username/repo): " REPO
read -p "Enter the secret name: " SECRET_NAME
read -p "Enter the secret value: " SECRET_VALUE

# Validate inputs
if [[ -z "$REPO" ]]; then
    handle_error "GitHub repository cannot be empty."
fi

if [[ -z "$SECRET_NAME" ]]; then
    handle_error "Secret name cannot be empty."
fi

if [[ -z "$SECRET_VALUE" ]]; then
    handle_error "Secret value cannot be empty."
fi

# Create the secret in the specified GitHub repository
echo "Creating secret '$SECRET_NAME' in repository '$REPO'..."
gh secret set $SECRET_NAME -b"$SECRET_VALUE" --repo $REPO

if [[ $? -ne 0 ]]; then
    handle_error "Failed to create secret."
fi

echo "Secret '$SECRET_NAME' created successfully in repository '$REPO'."