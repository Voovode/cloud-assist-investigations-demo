  # Cloud Assist Investigations Demo

  A hands-on demonstration of Google Cloud Assist Investigations with a reproducible memory leak scenario in Cloud Run.

  ## Blog Post

  Read the full tutorial: https://medium.com/@voovode/f173ceabaef4

  ## Quick Start

  This demo creates a Cloud Run service that intentionally leaks memory, allowing you to test Cloud Assist Investigations root cause analysis capabilities.

  ### Prerequisites

  - Google Cloud Project with billing enabled
  - gcloud CLI installed and configured
  - Appropriate IAM permissions

  ### Run the Demo

 ```
  # Clone the repository
  git clone https://github.com/Voovode/cloud-assist-investigations-demo.git
  cd cloud-assist-investigations-demo

  # Run setup (default region: europe-west1)
  ./setup-demo.sh

  # Or specify a different region
  ./setup-demo.sh us-central1

  # Trigger the memory issue
  ./trigger-issue.sh

  # Create investigation in the Console
  # Go to Logs Explorer > Find ERROR logs > Click Investigate

  # Cleanup when done
  ./cleanup-demo.sh
```

  ## Directory Structure

  ### What's Included

  - app.js - Node.js Express app with memory leak endpoint
  - setup-demo.sh - Automated setup script
  - trigger-issue.sh - Script to trigger the memory issue
  - cleanup-demo.sh - Resource cleanup script
  - slack-integration/ - Example Slack bot integration

  ### What This Demo Shows

  1. How to create investigations from the Console
  2. How to create investigations via API
  3. How Cloud Assist identifies root causes (memory exhaustion)
  4. Integration patterns for Slack, etc.

  ### Key Features

  - Fully automated setup
  - Reproducible failure scenario
  - Region-configurable (defaults to europe-west1)
  - Uses Artifact Registry (not deprecated Container Registry)
  - Complete cleanup scripts

  ### Expected Investigation Results

  When you run an investigation on the failed service, Cloud Assist will identify:

  - Container memory limit exceeded (256Mi)
  - Multiple container restarts
  - Memory usage spike pattern
  - /leak endpoint correlation

  Root Cause: Memory exhaustion due to application memory leakRecommendation: Increase memory limit or fix the leak

  ### Manual Steps

  If you prefer manual setup, see the blog post for detailed step-by-step instructions.

  ### Integration Examples

  The `slack-integration` Directory contains a complete example of:
  - Creating investigations from Slack alerts
  - Polling for results
  - Posting formatted results back to Slack threads
  - ++!