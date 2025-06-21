# Google Cloud Run Deployment Guide

This directory contains all the necessary files to deploy the Placetory Backoffice Laravel application to Google Cloud Run with Cloud SQL (MySQL) and Memory Store (Redis).

## Prerequisites

1. **Google Cloud SDK**: Install and authenticate
   ```bash
   # Install gcloud CLI
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   
   # Authenticate
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Docker**: Ensure Docker is installed and running

3. **Project Setup**: Create or select a Google Cloud project
   ```bash
   gcloud projects create your-project-id
   gcloud config set project your-project-id
   gcloud auth application-default set-quota-project your-project-id
   ```

## Quick Deployment

### Option 1: Automated Deployment (Recommended)

Run the automated deployment script:

```bash
# From the project root directory
cd deploy
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GOOGLE_CLOUD_REGION="us-central1"
./deploy.sh
```

This script will:
- Enable required Google Cloud APIs
- Create VPC network and connector
- Set up Cloud SQL (MySQL) instance
- Set up Memory Store (Redis) instance
- Build and deploy the Docker image
- Configure Cloud Run service with all environment variables

### Option 2: Manual Deployment

If you prefer manual control, follow these steps:

#### 1. Enable APIs
```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable sql-component.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable redis.googleapis.com
gcloud services enable vpcaccess.googleapis.com
```

#### 2. Create VPC Network
```bash
gcloud compute networks create placetory-vpc --subnet-mode regional
gcloud compute networks subnets create placetory-subnet \
    --network=placetory-vpc \
    --range=10.0.0.0/24 \
    --region=us-central1
```

#### 3. Create VPC Access Connector
```bash
gcloud compute networks vpc-access connectors create placetory-connector \
    --region=us-central1 \
    --subnet=placetory-subnet \
    --subnet-project=your-project-id \
    --min-instances=2 \
    --max-instances=3
```

#### 4. Set up Cloud SQL
```bash
# Create instance
gcloud sql instances create placetory-db \
    --database-version=MYSQL_8_0 \
    --tier=db-f1-micro \
    --region=us-central1 \
    --network=placetory-vpc \
    --no-assign-ip

# Create user and database
gcloud sql users create laravel \
    --instance=placetory-db \
    --password=your-secure-password

gcloud sql databases create placetory \
    --instance=placetory-db
```

#### 5. Set up Redis
```bash
gcloud redis instances create placetory-redis \
    --size=1 \
    --region=us-central1 \
    --network=placetory-vpc \
    --redis-version=redis_7_0
```

#### 6. Build and Deploy
```bash
# Build image
gcloud builds submit --tag gcr.io/your-project-id/placetory-backoffice

# Deploy to Cloud Run
gcloud run deploy placetory-backoffice \
    --image gcr.io/your-project-id/placetory-backoffice \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --vpc-connector placetory-connector \
    --set-env-vars "APP_ENV=production,APP_DEBUG=false,..."
```

## Database Migrations

After deployment, run database migrations:

```bash
# Using the migration script
./migrate.sh

# Or manually create and execute a Cloud Run Job
gcloud run jobs create placetory-migration \
    --image gcr.io/your-project-id/placetory-backoffice \
    --region us-central1 \
    --command "php" \
    --args "artisan,migrate,--force"

gcloud run jobs execute placetory-migration --region us-central1 --wait
```

## Environment Configuration

The deployment script automatically configures environment variables. Key variables include:

- `APP_KEY`: Generated automatically during deployment
- `DB_*`: Database connection details from Cloud SQL
- `REDIS_*`: Redis connection details from Memory Store
- `OCTANE_SERVER=frankenphp`: Uses FrankenPHP for high performance

## Files Overview

- **`Dockerfile`**: Multi-stage Docker build with FrankenPHP
- **`deploy.sh`**: Automated deployment script
- **`migrate.sh`**: Database migration script
- **`cloud-run.yaml`**: Declarative Cloud Run service configuration
- **`cloudbuild.yaml`**: Cloud Build configuration for CI/CD
- **`.env.production`**: Environment variables template
- **`frankenphp/Caddyfile`**: FrankenPHP/Caddy configuration

## Monitoring and Maintenance

### Health Checks
The application includes a `/health` endpoint for monitoring.

### Logs
View application logs:
```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=placetory-backoffice" --limit 50
```

### Scaling
Cloud Run automatically scales based on traffic. Configuration:
- Min instances: 0 (scales to zero when no traffic)
- Max instances: 10
- CPU: 1 vCPU
- Memory: 512 MB

### Updates
To update the application:
1. Push changes to your repository
2. Run the deployment script again
3. Run migrations if needed

## Security Considerations

- VPC network isolates resources
- Cloud SQL uses private IP
- Redis uses private IP
- No public IP addresses assigned to database services
- Environment variables are securely managed by Cloud Run

## Cost Optimization

- Uses `db-f1-micro` for Cloud SQL (lowest cost tier)
- Redis with 1GB memory (minimal size)
- Cloud Run scales to zero when not in use
- VPC connector with minimal instances

## Troubleshooting

### Common Issues

1. **Build Failures**: Check Cloud Build logs
2. **Database Connection**: Verify VPC connector and private IPs
3. **Redis Connection**: Ensure Redis instance is in the same VPC
4. **Permission Errors**: Check IAM roles and service accounts

### Debug Commands
```bash
# Check service status
gcloud run services describe placetory-backoffice --region us-central1

# View logs
gcloud logging read "resource.type=cloud_run_revision" --limit 10

# Test connectivity
gcloud run services proxy placetory-backoffice --port 8080
```

## Support

For issues with this deployment:
1. Check the Cloud Run logs
2. Verify all Google Cloud services are enabled
3. Ensure VPC connectivity is properly configured
4. Check environment variables are set correctly
