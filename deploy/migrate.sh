#!/bin/bash

# Database Migration Job for Google Cloud Run
# This script creates and runs database migrations in Cloud Run Jobs

set -e

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-your-project-id}"
REGION="${GOOGLE_CLOUD_REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-placetory-backoffice}"
JOB_NAME="${SERVICE_NAME}-migration"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "🗄️  Running database migrations..."

# Create migration job if it doesn't exist
if ! gcloud run jobs describe ${JOB_NAME} --region=${REGION} &> /dev/null; then
    echo "📋 Creating migration job..."
    gcloud run jobs create ${JOB_NAME} \
        --image ${IMAGE_NAME} \
        --region ${REGION} \
        --memory 512Mi \
        --cpu 1 \
        --max-retries 3 \
        --parallelism 1 \
        --task-count 1 \
        --vpc-connector placetory-connector \
        --vpc-egress private-ranges-only \
        --set-env-vars "APP_ENV=production" \
        --set-env-vars "APP_DEBUG=false" \
        --command "php" \
        --args "artisan,migrate,--force"
fi

# Execute the migration job
echo "🚀 Executing migrations..."
gcloud run jobs execute ${JOB_NAME} --region=${REGION} --wait

echo "✅ Database migrations completed successfully!"
