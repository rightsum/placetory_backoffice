#!/bin/bash

# Quick Setup Script for Google Cloud Run Deployment
# This script helps you configure the deployment quickly

set -e

echo "🚀 Placetory Backoffice - Google Cloud Run Setup"
echo "================================================="
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud SDK not found."
    echo "📥 Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo "🔐 Please authenticate with Google Cloud:"
    gcloud auth login
    gcloud auth application-default login
fi

# Get project ID
if [ -z "${GOOGLE_CLOUD_PROJECT}" ]; then
    echo "📋 Enter your Google Cloud Project ID:"
    read -r PROJECT_ID
    export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
else
    PROJECT_ID="$GOOGLE_CLOUD_PROJECT"
fi

# Get region
if [ -z "${GOOGLE_CLOUD_REGION}" ]; then
    echo "🌍 Enter your preferred region (default: us-central1):"
    read -r REGION
    REGION="${REGION:-us-central1}"
    export GOOGLE_CLOUD_REGION="$REGION"
else
    REGION="$GOOGLE_CLOUD_REGION"
fi

echo ""
echo "Configuration:"
echo "  Project: $PROJECT_ID"
echo "  Region: $REGION"
echo ""

# Set gcloud project
gcloud config set project "$PROJECT_ID"

# Confirm deployment
echo "🚨 This will create resources in Google Cloud that may incur charges."
echo "📊 Estimated monthly cost: ~$10-30 for minimal usage"
echo ""
echo "Resources to be created:"
echo "  • VPC Network and Connector"
echo "  • Cloud SQL instance (db-f1-micro)"
echo "  • Memory Store Redis (1GB)"
echo "  • Cloud Run service"
echo ""
echo "Do you want to proceed? (y/N)"
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled."
    exit 0
fi

echo ""
echo "🚀 Starting deployment..."

# Run the deployment
./deploy.sh

echo ""
echo "🎉 Deployment completed!"
echo ""
echo "📝 Next steps:"
echo "  1. Run migrations: make deploy-migrate"
echo "  2. Visit your application at the provided URL"
echo "  3. Configure your custom domain (optional)"
echo "  4. Set up monitoring and alerts"
echo ""
echo "📚 For more information, see deploy/README.md"
