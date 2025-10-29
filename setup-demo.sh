#!/bin/bash

# Cloud Assist Investigations Demo Setup Script
# This script sets up a reproducible demo for Cloud Assist Investigations
# Usage: ./setup-demo.sh [REGION]
# Example: ./setup-demo.sh europe-west2

set -e

echo "=================================="
echo "Cloud Assist Investigations Demo"
echo "=================================="
echo

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Get region from command line argument or environment variable, default to europe-west1
if [ ! -z "$1" ]; then
    REGION=$1
else
    REGION=${REGION:-europe-west1}
fi

# Get or set project ID
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project)
    if [ -z "$PROJECT_ID" ]; then
        echo "Error: No project set. Please run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
fi

echo "Using Project: $PROJECT_ID"
echo "Using Region: $REGION"
echo

# Step 1: Enable required APIs
echo "Step 1: Enabling required APIs..."
gcloud services enable \
  geminicloudassist.googleapis.com \
  cloudaicompanion.googleapis.com \
  cloudasset.googleapis.com \
  cloudresourcemanager.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com

echo "✓ APIs enabled"
echo

# Step 2: Grant IAM permissions
echo "Step 2: Granting IAM permissions..."
USER_EMAIL=$(gcloud config get-value account)

# Grant investigation creator role to the user
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/geminicloudassist.investigationCreator" \
  --condition=None \
  --quiet || true

# Get the project number for the service agent
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# Grant Cloud Run Service Agent role to the service agent (fixes deployment permission issues)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:service-${PROJECT_NUMBER}@serverless-robot-prod.iam.gserviceaccount.com" \
  --role="roles/run.serviceAgent" \
  --quiet || true

echo "✓ IAM permissions granted"
echo

# Step 3: Create Artifact Registry repository
echo "Step 3: Creating Artifact Registry repository..."
gcloud artifacts repositories create cloud-assist-demos \
  --repository-format=docker \
  --location=$REGION \
  --description="Repository for Cloud Assist demo images" \
  --quiet 2>/dev/null || echo "Repository already exists"

# Configure Docker authentication for Artifact Registry
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

echo "✓ Artifact Registry repository ready"
echo

# Step 4: Build and deploy the application
echo "Step 4: Building and deploying Cloud Run service..."
echo "Building container image..."
IMAGE_URL="$REGION-docker.pkg.dev/$PROJECT_ID/cloud-assist-demos/cloud-assist-demo"
gcloud builds submit --tag $IMAGE_URL --quiet

echo "Deploying to Cloud Run..."
gcloud run deploy cloud-assist-demo \
  --image $IMAGE_URL \
  --region $REGION \
  --memory 256Mi \
  --allow-unauthenticated \
  --max-instances 3 \
  --quiet

SERVICE_URL=$(gcloud run services describe cloud-assist-demo \
  --region $REGION \
  --format 'value(status.url)')

echo "✓ Service deployed at: $SERVICE_URL"
echo

# Step 5: Test the service
echo "Step 5: Testing the service..."
echo "Making a normal request..."
curl -s $SERVICE_URL
echo
echo "✓ Service is responding"
echo

# Step 6: Instructions for triggering the issue
echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo
echo "Your Cloud Run service is deployed at: $SERVICE_URL"
echo
echo "To trigger the memory issue and create an investigation:"
echo
echo "1. Trigger the memory leak (run this command multiple times):"
echo "   for i in {1..10}; do curl $SERVICE_URL/leak & done; wait"
echo
echo "2. Wait for errors to appear (usually within 30-60 seconds)"
echo
echo "3. Go to Logs Explorer in the Console:"
echo "   https://console.cloud.google.com/logs/query"
echo
echo "4. Look for ERROR logs from 'cloud-assist-demo' service"
echo
echo "5. Click on any ERROR log entry and click 'Investigate'"
echo
echo "Or create an investigation via API using the provided investigation.json"
echo

# Create investigation.json template with the selected region
cat > investigation.json <<EOF
{
  "title": "Cloud Run Memory Issue Investigation",
  "observations": {
    "user.project": {
      "id": "user.project",
      "observationType": "OBSERVATION_TYPE_STRUCTURED_INPUT",
      "observerType": "OBSERVER_TYPE_USER",
      "text": "$PROJECT_ID"
    },
    "user.input.text": {
      "id": "user.input.text",
      "observationType": "OBSERVATION_TYPE_TEXT_DESCRIPTION",
      "observerType": "OBSERVER_TYPE_USER",
      "timeIntervals": [{
        "startTime": "$(date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')"
      }],
      "text": "Cloud Run service cloud-assist-demo returning 500 errors and container restarts",
      "relevantResources": [
        "//run.googleapis.com/projects/$PROJECT_ID/locations/$REGION/services/cloud-assist-demo"
      ]
    }
  }
}
EOF

echo "investigation.json created for API-based investigation"
echo
echo "To cleanup when done, run: ./cleanup-demo.sh $REGION"
echo "(or just ./cleanup-demo.sh if REGION env var is set to $REGION)"