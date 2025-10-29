# Slack Integration for Cloud Assist Investigations

This integration allows you to create Cloud Assist Investigations from Slack and automatically post results back to your Slack threads.

## Features

- ✅ Create investigations from Slack slash commands or alerts
- ✅ Post investigation link to Slack for immediate access
- ✅ Automatically poll for results (every 15 seconds)
- ✅ Format and post results back to the same Slack thread
- ✅ Include observations, root causes, and recommended actions
- ✅ 5-minute timeout protection

## Prerequisites

1. **Slack App with Bot Token**
   - Create a Slack App at https://api.slack.com/apps
   - Add Bot Token Scopes: `chat:write`, `commands`
   - Install app to your workspace
   - Copy the Bot User OAuth Token (starts with `xoxb-`)

2. **Google Cloud Setup**
   - Cloud Assist Investigations API enabled
   - Service account or user credentials with `investigationCreator` role
   - Application Default Credentials configured

3. **Python 3.8+**

## Installation

```bash
pip install -r requirements.txt
```

## Configuration

Set environment variables:

```bash
export SLACK_BOT_TOKEN="xoxb-your-token-here"
export GCP_PROJECT_ID="your-project-id"
```

Or configure in your deployment (Cloud Functions, Cloud Run, etc.)

## Usage

### As a Library

```python
from investigation_bot import SlackInvestigationBot

bot = SlackInvestigationBot(
    slack_token="xoxb-your-token",
    project_id="your-gcp-project"
)

# Trigger from an alert or slash command
bot.create_and_monitor_investigation(
    channel_id="C1234567890",
    thread_ts="1234567890.123456",
    error_message="Cloud Run service returning 500 errors",
    resource="//run.googleapis.com/projects/my-project/locations/europe-west1/services/my-service"
)
```

### As a Slash Command

1. Create a Slack slash command (e.g., `/investigate`)
2. Point it to your webhook/function that calls `handle_slack_command()`
3. Usage: `/investigate "Error description" //resource-url`

### Integration with Alerting

Connect to your monitoring alerts:

```python
# In your alert webhook handler
def handle_alert(alert_data):
    bot = SlackInvestigationBot(
        slack_token=SLACK_TOKEN,
        project_id=PROJECT_ID
    )

    bot.create_and_monitor_investigation(
        channel_id=alert_data['channel'],
        thread_ts=alert_data['thread'],
        error_message=alert_data['description'],
        resource=alert_data['resource_url']
    )
```

## Deployment Options

### Cloud Functions

Deploy as a Cloud Function triggered by Pub/Sub or HTTP:

```bash
gcloud functions deploy slack-investigation-bot \
  --runtime python311 \
  --trigger-http \
  --entry-point handle_slack_command \
  --set-env-vars SLACK_BOT_TOKEN=xoxb-...,GCP_PROJECT_ID=my-project
```

### Cloud Run

Deploy as a container on Cloud Run:

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY investigation_bot.py .
CMD ["python", "investigation_bot.py"]
```

### Kubernetes

Deploy as a Job or CronJob for scheduled investigations.

## Output Format

When an investigation completes, the bot posts to Slack:

```
✅ Investigation Complete

Top Observations:
🔴 Container memory limit exceeded - 256Mi limit reached
🟡 Multiple container restarts in the past 10 minutes
🟡 Memory usage spike detected before crash

Root Cause Hypotheses:
1. Memory exhaustion due to application memory leak
   Confidence: 94%
   Gradual memory increase detected with OOMKilled events

Recommended Actions:
• Increase memory limit to 512Mi
• Review /leak endpoint for memory management issues
• Implement memory profiling and monitoring alerts
```

## Customization

### Adjust Polling Interval

Change the polling frequency in `create_and_monitor_investigation()`:

```python
time.sleep(15)  # Check every 15 seconds (default)
time.sleep(30)  # Check every 30 seconds
```

### Timeout Configuration

Modify the timeout duration:

```python
while time.time() - start_time < 300:  # 5 minutes (default)
while time.time() - start_time < 600:  # 10 minutes
```

### Custom Result Formatting

Override `_post_results_to_slack()` to customize the Slack message format.

## Troubleshooting

### Bot not posting messages

- Verify bot token is correct
- Check bot has `chat:write` scope
- Ensure bot is invited to the channel

### Investigations not created

- Verify GCP project ID is correct
- Check IAM permissions for Investigation Creator role
- Ensure Cloud Assist APIs are enabled

### Timeout issues

- Investigations typically complete in 1-2 minutes
- If timing out consistently, check if the service is experiencing issues
- View investigation status in Console for more details

## Security Notes

- Store Slack tokens securely (Secret Manager, environment variables)
- Use service accounts with minimal required permissions
- Implement rate limiting for slash commands
- Validate input to prevent command injection

## Support

For issues or questions, see the main repository README or open an issue.
