#!/bin/bash

# Script to trigger the memory issue for demonstration purposes
# Usage: ./trigger-issue.sh [REGION]
# Example: ./trigger-issue.sh europe-west2

set -e

# Get region from command line argument or environment variable, default to europe-west1
if [ ! -z "$1" ]; then
    REGION=$1
else
    REGION=${REGION:-europe-west1}
fi

# Get project ID
PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project)}

echo "=================================="
echo "Triggering Memory Issue Demo"
echo "=================================="
echo

# Get service URL
SERVICE_URL=$(gcloud run services describe cloud-assist-demo \
  --region $REGION \
  --format 'value(status.url)' 2>/dev/null)

if [ -z "$SERVICE_URL" ]; then
    echo "Error: Cloud Run service 'cloud-assist-demo' not found."
    echo "Please run ./setup-demo.sh first."
    exit 1
fi

echo "Service URL: $SERVICE_URL"
echo

# Test normal endpoint
echo "Testing normal endpoint..."
curl -s $SERVICE_URL
echo -e "\n✓ Normal endpoint working"
echo

# Trigger memory leak
echo "Triggering memory leak..."
echo "This will make 10 concurrent requests to the /leak endpoint"
echo

for i in {1..10}; do
    echo "Request $i..."
    curl -s $SERVICE_URL/leak &
done

echo
echo "Waiting for all requests to complete..."
wait

echo
echo "✓ Memory leak triggered!"
echo

# Check for errors
echo "Checking service status..."
sleep 5

# Try to access the service again
echo "Testing if service is still responsive..."
if curl -s --max-time 5 $SERVICE_URL > /dev/null 2>&1; then
    echo "Service is still responding. You may need to:"
    echo "1. Run this script again to trigger more memory consumption"
    echo "2. Wait a bit longer for the container to crash"
else
    echo "✓ Service appears to be failing (as expected for the demo)"
fi

echo
echo "=================================="
echo "Next Steps:"
echo "=================================="
echo "1. Go to Logs Explorer:"
echo "   https://console.cloud.google.com/logs/query"
echo
echo "2. Filter for your service:"
echo "   resource.type=\"cloud_run_revision\""
echo "   resource.labels.service_name=\"cloud-assist-demo\""
echo "   severity>=ERROR"
echo
echo "3. Click on any ERROR log entry"
echo
echo "4. Click the 'Investigate' button to create an investigation"
echo
echo "Or use the API with the investigation.json file"