#!/bin/bash

# Google Cloud Run Deployment Script
# This script deploys the Laravel application to Google Cloud Run
# with Cloud SQL (PostgreSQL) and Memory Store (Redis)

set -e

# Configuration
PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-your-project-id}"
REGION="${GOOGLE_CLOUD_REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-placetory-backoffice}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Database configuration
DB_INSTANCE_NAME="${DB_INSTANCE_NAME:-placetory-db}"
DB_NAME="${DB_NAME:-placetory_backoffice}"
DB_USER="${DB_USER:-laravel}"

# Redis configuration
REDIS_INSTANCE_NAME="${REDIS_INSTANCE_NAME:-placetory-redis}"

echo "🚀 Starting deployment to Google Cloud Run..."
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Service: ${SERVICE_NAME}"

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud SDK not found. Please install it first."
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo "❌ Not authenticated with Google Cloud. Please run 'gcloud auth login'"
    exit 1
fi

# Set the project
echo "📋 Setting project to ${PROJECT_ID}..."
gcloud config set project "${PROJECT_ID}"

# Enable required APIs
echo "🔧 Enabling required Google Cloud APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable sql-component.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable redis.googleapis.com
gcloud services enable vpcaccess.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com

# Create VPC network for private communication
echo "🌐 Creating VPC network..."
if ! gcloud compute networks describe ${SERVICE_NAME}-vpc &> /dev/null; then
    gcloud compute networks create ${SERVICE_NAME}-vpc --subnet-mode custom
    
    # Create main subnet for database and Redis (larger range)
    gcloud compute networks subnets create ${SERVICE_NAME}-subnet \
        --network=${SERVICE_NAME}-vpc \
        --range=10.0.0.0/24 \
        --region=${REGION}
    
    # Create dedicated subnet for VPC connector (requires /28 netmask)
    gcloud compute networks subnets create ${SERVICE_NAME}-connector-subnet \
        --network=${SERVICE_NAME}-vpc \
        --range=10.0.1.0/28 \
        --region=${REGION}
fi

# VPC Access Connector name (must be lowercase alphanumeric + hyphens, max 25 chars)
CONNECTOR_NAME="placetory-connector"

# Create VPC Access Connector
echo "🔗 Creating VPC Access Connector..."
if ! gcloud compute networks vpc-access connectors describe ${CONNECTOR_NAME} --region=${REGION} &> /dev/null; then
    gcloud compute networks vpc-access connectors create ${CONNECTOR_NAME} \
        --region=${REGION} \
        --subnet=${SERVICE_NAME}-connector-subnet \
        --subnet-project=${PROJECT_ID} \
        --min-instances=2 \
        --max-instances=3
fi

# Configure Service Networking for Cloud SQL private IP
echo "🔗 Configuring Service Networking for Cloud SQL..."
if ! gcloud compute addresses describe google-managed-services-${SERVICE_NAME}-vpc --global &> /dev/null; then
    # Reserve an IP range for Google services
    gcloud compute addresses create google-managed-services-${SERVICE_NAME}-vpc \
        --global \
        --purpose=VPC_PEERING \
        --prefix-length=16 \
        --network=${SERVICE_NAME}-vpc
    
    # Create the peering connection
    gcloud services vpc-peerings connect \
        --service=servicenetworking.googleapis.com \
        --ranges=google-managed-services-${SERVICE_NAME}-vpc \
        --network=${SERVICE_NAME}-vpc \
        --project=${PROJECT_ID}
fi

# Create Cloud SQL instance
echo "🗄️  Creating Cloud SQL instance..."
if ! gcloud sql instances describe ${DB_INSTANCE_NAME} &> /dev/null; then
    # Generate a random password for the database
    DB_PASSWORD=$(openssl rand -base64 32)
    
    gcloud sql instances create ${DB_INSTANCE_NAME} \
        --database-version=POSTGRES_15 \
        --tier=db-f1-micro \
        --region=${REGION} \
        --network=${SERVICE_NAME}-vpc \
        --no-assign-ip \
        --deletion-protection \
        --backup-start-time=03:00
    
    # Create database user
    gcloud sql users create ${DB_USER} \
        --instance=${DB_INSTANCE_NAME} \
        --password=${DB_PASSWORD}
    
    # Create database
    gcloud sql databases create ${DB_NAME} \
        --instance=${DB_INSTANCE_NAME}
    
    echo "📝 Database password: ${DB_PASSWORD}"
    echo "⚠️  Save this password securely - it won't be shown again!"
else
    echo "ℹ️  Cloud SQL instance already exists"
fi

# Get Cloud SQL connection name
SQL_CONNECTION_NAME=$(gcloud sql instances describe ${DB_INSTANCE_NAME} --format="value(connectionName)")
SQL_PRIVATE_IP=$(gcloud sql instances describe ${DB_INSTANCE_NAME} --format="value(ipAddresses[0].ipAddress)")

# Create Redis instance
echo "🔴 Creating Redis instance..."
if ! gcloud redis instances describe ${REDIS_INSTANCE_NAME} --region=${REGION} &> /dev/null; then
    gcloud redis instances create ${REDIS_INSTANCE_NAME} \
        --size=1 \
        --region=${REGION} \
        --network=${SERVICE_NAME}-vpc \
        --redis-version=redis_7_0
else
    echo "ℹ️  Redis instance already exists"
fi

# Get Redis details
REDIS_HOST=$(gcloud redis instances describe ${REDIS_INSTANCE_NAME} --region=${REGION} --format="value(host)")
REDIS_PORT=$(gcloud redis instances describe ${REDIS_INSTANCE_NAME} --region=${REGION} --format="value(port)")

# Build and push Docker image
echo "🐳 Building Docker image..."
cd "$(dirname "$0")/.."

# Build image using Cloud Build
gcloud builds submit --config cloudbuild.yaml

# Generate APP_KEY if not provided
if [ -z "${APP_KEY}" ]; then
    APP_KEY=$(openssl rand -base64 32)
    echo "🔑 Generated APP_KEY: ${APP_KEY}"
    echo "⚠️  Save this key securely - it's required for the application!"
fi

# Deploy to Cloud Run
echo "☁️  Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME} \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --port 8080 \
    --memory 512Mi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 10 \
    --vpc-connector ${CONNECTOR_NAME} \
    --vpc-egress private-ranges-only \
    --set-env-vars "APP_NAME=Placetory Backoffice" \
    --set-env-vars "APP_ENV=production" \
    --set-env-vars "APP_DEBUG=false" \
    --set-env-vars "APP_KEY=base64:${APP_KEY}" \
    --set-env-vars "APP_URL=https://${SERVICE_NAME}-${PROJECT_ID}.a.run.app" \
    --set-env-vars "LOG_CHANNEL=errorlog" \
    --set-env-vars "LOG_LEVEL=info" \
    --set-env-vars "DB_CONNECTION=pgsql" \
    --set-env-vars "DB_HOST=${SQL_PRIVATE_IP}" \
    --set-env-vars "DB_PORT=5432" \
    --set-env-vars "DB_DATABASE=${DB_NAME}" \
    --set-env-vars "DB_USERNAME=${DB_USER}" \
    --set-env-vars "DB_PASSWORD=${DB_PASSWORD}" \
    --set-env-vars "REDIS_HOST=${REDIS_HOST}" \
    --set-env-vars "REDIS_PORT=${REDIS_PORT}" \
    --set-env-vars "REDIS_PASSWORD=" \
    --set-env-vars "CACHE_DRIVER=redis" \
    --set-env-vars "SESSION_DRIVER=redis" \
    --set-env-vars "QUEUE_CONNECTION=redis" \
    --set-env-vars "OCTANE_SERVER=frankenphp"

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format="value(status.url)")

echo "✅ Deployment completed successfully!"
echo "🌍 Service URL: ${SERVICE_URL}"
echo "🗄️  Database: ${SQL_CONNECTION_NAME}"
echo "🔴 Redis: ${REDIS_INSTANCE_NAME}"
echo ""
echo "🚨 Important: Save these credentials securely:"
echo "   APP_KEY: base64:${APP_KEY}"
if [ ! -z "${DB_PASSWORD}" ]; then
    echo "   DB_PASSWORD: ${DB_PASSWORD}"
fi
echo ""
echo "🔧 Next steps:"
echo "   1. Update your DNS to point to the Cloud Run service"
echo "   2. Configure your domain in Cloud Run"
echo "   3. Run database migrations: gcloud run jobs create migration-job ..."
echo "   4. Set up monitoring and alerting"
