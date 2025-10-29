#!/bin/bash

# Cloud Assist Investigations Demo Cleanup Script
# This script removes all resources created by the demo
# Usage: ./cleanup-demo.sh [REGION]
# Example: ./cleanup-demo.sh europe-west2

set -e

echo "=================================="
echo "Cloud Assist Demo Cleanup"
echo "=================================="
echo

# Get region from command line argument or environment variable, default to europe-west1
if [ ! -z "$1" ]; then
    REGION=$1
else
    REGION=${REGION:-europe-west1}
fi

# Get project ID
PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project)}

echo "Cleaning up resources in project: $PROJECT_ID"
echo "Region: $REGION"
echo

# Delete Cloud Run service
echo "Deleting Cloud Run service..."
gcloud run services delete cloud-assist-demo --region $REGION --quiet 2>/dev/null || echo "Service not found or already deleted"
echo "✓ Cloud Run service deleted"

# Delete container image from Artifact Registry
echo "Deleting container image..."
IMAGE_URL="$REGION-docker.pkg.dev/$PROJECT_ID/cloud-assist-demos/cloud-assist-demo"
gcloud artifacts docker images delete $IMAGE_URL --quiet 2>/dev/null || echo "Image not found or already deleted"
echo "✓ Container image deleted"

# Remove local files
echo "Removing local files..."
rm -f investigation.json
echo "✓ Local files removed"

# Optionally delete the Artifact Registry repository
echo
read -p "Delete the Artifact Registry repository 'cloud-assist-demos'? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting Artifact Registry repository..."
    gcloud artifacts repositories delete cloud-assist-demos \
      --location=$REGION --quiet 2>/dev/null || echo "Repository not found or already deleted"
    echo "✓ Artifact Registry repository deleted"
fi

echo
echo "=================================="
echo "Cleanup Complete!"
echo "=================================="
echo
echo "All demo resources have been removed."
echo "The following APIs remain enabled (you may want to keep them):"
echo "- geminicloudassist.googleapis.com"
echo "- cloudaicompanion.googleapis.com"
echo "- cloudasset.googleapis.com"
echo
echo "To disable these APIs, run:"
echo "gcloud services disable geminicloudassist.googleapis.com cloudaicompanion.googleapis.com cloudasset.googleapis.com"