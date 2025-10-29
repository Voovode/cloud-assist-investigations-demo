"""
Cloud Assist Investigations Slack Bot

This bot integrates Google Cloud Assist Investigations with Slack, allowing you to:
- Create investigations from Slack alerts or slash commands
- Automatically poll for investigation results
- Post formatted results back to the Slack thread

Dependencies:
    pip install slack-sdk google-auth requests

Usage:
    from investigation_bot import SlackInvestigationBot

    bot = SlackInvestigationBot(
        slack_token="xoxb-your-token",
        project_id="your-project-id"
    )

    bot.create_and_monitor_investigation(
        channel_id="C1234567890",
        thread_ts="1234567890.123456",
        error_message="Cloud Run service returning 500 errors",
        resource="//run.googleapis.com/projects/..."
    )
"""

import requests
import json
import time
from datetime import datetime
from google.auth import default
from google.auth.transport.requests import Request
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError


class SlackInvestigationBot:
    def __init__(self, slack_token, project_id):
        self.slack_client = WebClient(token=slack_token)
        self.project_id = project_id
        self.credentials, _ = default()

    def create_and_monitor_investigation(self, channel_id, thread_ts, error_message, resource):
        """Create investigation and post results back to Slack thread"""

        try:
            # Post initial message
            self.slack_client.chat_postMessage(
                channel=channel_id,
                thread_ts=thread_ts,
                text="🔍 Creating Cloud Assist Investigation..."
            )

            # Create investigation
            investigation_response = self._create_investigation(error_message, resource)

            if 'error' in investigation_response:
                self.slack_client.chat_postMessage(
                    channel=channel_id,
                    thread_ts=thread_ts,
                    text=f"❌ Failed to create investigation: {investigation_response['error']['message']}"
                )
                return

            revision = investigation_response.get('revision')
            investigation_id = investigation_response.get('name', '').split('/')[-1]

            # Run investigation
            self._run_investigation(revision)

            # Post investigation link
            console_url = f"https://console.cloud.google.com/gemini/cloud-assist/investigations/{investigation_id}?project={self.project_id}"
            self.slack_client.chat_postMessage(
                channel=channel_id,
                thread_ts=thread_ts,
                blocks=[
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"🚀 Investigation started!\n<{console_url}|View in Console>"
                        }
                    }
                ]
            )

            # Poll for results (timeout after 5 minutes)
            start_time = time.time()
            while time.time() - start_time < 300:  # 5 minute timeout
                investigation = self._get_investigation(investigation_response['name'])

                if investigation.get('state') == 'COMPLETED':
                    self._post_results_to_slack(channel_id, thread_ts, investigation)
                    break
                elif investigation.get('state') == 'FAILED':
                    self.slack_client.chat_postMessage(
                        channel=channel_id,
                        thread_ts=thread_ts,
                        text="❌ Investigation failed. Check the console for details."
                    )
                    break

                time.sleep(15)  # Check every 15 seconds
            else:
                self.slack_client.chat_postMessage(
                    channel=channel_id,
                    thread_ts=thread_ts,
                    text="⏱️ Investigation timed out after 5 minutes. Check console for results."
                )

        except Exception as e:
            self.slack_client.chat_postMessage(
                channel=channel_id,
                thread_ts=thread_ts,
                text=f"❌ Error: {str(e)}"
            )

    def _create_investigation(self, error_message, resource):
        """Create the investigation via API"""
        self.credentials.refresh(Request())

        investigation = {
            "title": f"Slack Alert: {error_message[:50]}",
            "observations": {
                "user.project": {
                    "id": "user.project",
                    "observationType": "OBSERVATION_TYPE_STRUCTURED_INPUT",
                    "observerType": "OBSERVER_TYPE_USER",
                    "text": self.project_id
                },
                "user.input.text": {
                    "id": "user.input.text",
                    "observationType": "OBSERVATION_TYPE_TEXT_DESCRIPTION",
                    "observerType": "OBSERVER_TYPE_USER",
                    "timeIntervals": [{
                        "startTime": datetime.utcnow().isoformat() + "Z"
                    }],
                    "text": error_message,
                    "relevantResources": [resource] if resource else []
                }
            }
        }

        headers = {
            "Authorization": f"Bearer {self.credentials.token}",
            "Content-Type": "application/json"
        }

        url = f"https://geminicloudassist.googleapis.com/v1alpha/projects/{self.project_id}/locations/global/investigations"
        response = requests.post(url, json=investigation, headers=headers)
        return response.json()

    def _run_investigation(self, revision):
        """Run the investigation"""
        self.credentials.refresh(Request())

        headers = {"Authorization": f"Bearer {self.credentials.token}"}
        url = f"https://geminicloudassist.googleapis.com/v1alpha/{revision}:run"
        requests.post(url, headers=headers)

    def _get_investigation(self, investigation_name):
        """Get investigation status and results"""
        self.credentials.refresh(Request())

        headers = {"Authorization": f"Bearer {self.credentials.token}"}
        url = f"https://geminicloudassist.googleapis.com/v1alpha/{investigation_name}"
        response = requests.get(url, headers=headers)
        return response.json()

    def _post_results_to_slack(self, channel_id, thread_ts, investigation):
        """Format and post investigation results to Slack"""

        # Extract top observations
        observations = investigation.get('observations', {})
        top_observations = sorted(
            [(k, v) for k, v in observations.items() if 'relevanceScore' in v],
            key=lambda x: x[1].get('relevanceScore', 0),
            reverse=True
        )[:5]

        # Extract hypotheses
        hypotheses = investigation.get('diagnoses', [])

        # Build Slack message blocks
        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "✅ Investigation Complete"
                }
            },
            {
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*Top Observations:*"
                }
            }
        ]

        # Add observations
        for obs_id, obs in top_observations:
            severity = "🔴" if obs.get('severity') == 'HIGH' else "🟡"
            blocks.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"{severity} {obs.get('text', 'No description')[:200]}"
                }
            })

        # Add hypotheses
        if hypotheses:
            blocks.append({
                "type": "divider"
            })
            blocks.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*Root Cause Hypotheses:*"
                }
            })

            for i, hypothesis in enumerate(hypotheses[:2], 1):
                confidence = hypothesis.get('confidence', 0) * 100
                blocks.append({
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"*{i}. {hypothesis.get('title', 'Hypothesis')}*\n"
                                f"Confidence: {confidence:.0f}%\n"
                                f"{hypothesis.get('description', '')[:200]}"
                    }
                })

        # Add recommended actions
        if investigation.get('recommendedActions'):
            blocks.append({
                "type": "divider"
            })
            blocks.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Recommended Actions:*\n" +
                            "\n".join([f"• {action}" for action in investigation['recommendedActions'][:3]])
                }
            })

        # Post to Slack
        self.slack_client.chat_postMessage(
            channel=channel_id,
            thread_ts=thread_ts,
            blocks=blocks
        )


# Example usage in a Slack slash command handler
def handle_slack_command(command_text, channel_id, thread_ts):
    """Handler for Slack slash command /investigate"""

    bot = SlackInvestigationBot(
        slack_token="xoxb-your-slack-bot-token",
        project_id="your-project-id"
    )

    # Parse the command to extract error and resource
    # Example: /investigate "Cloud Run 500 errors" //run.googleapis.com/projects/...
    parts = command_text.split('"')
    error_message = parts[1] if len(parts) > 1 else command_text
    resource = parts[2].strip() if len(parts) > 2 else None

    # Create investigation and monitor results
    bot.create_and_monitor_investigation(
        channel_id=channel_id,
        thread_ts=thread_ts,
        error_message=error_message,
        resource=resource
    )


if __name__ == "__main__":
    # Example test usage
    import os

    bot = SlackInvestigationBot(
        slack_token=os.environ.get('SLACK_BOT_TOKEN'),
        project_id=os.environ.get('GCP_PROJECT_ID')
    )

    # Test with a sample investigation
    bot.create_and_monitor_investigation(
        channel_id=os.environ.get('SLACK_CHANNEL_ID'),
        thread_ts=os.environ.get('SLACK_THREAD_TS'),
        error_message="Test investigation from Cloud Assist demo",
        resource=None
    )
