#!/bin/bash

JENKINS_URL="http://localhost:8080"        # Jenkins server URL
# ALWAYS BEST to use Jenkins secret manager plugin
JENKINS_TOKEN=$(aws secretsmanager get-secret-value \
   --secret-id jenkins-monitor-token \
   --query SecretString --output text)

AUTH="monitor:${JENKINS_TOKEN}"
CLI="jenkins-cli"                         # Jenkins CLI command; may need full path or 'java -jar jenkins-cli.jar' depending on setup
UPDATE_CENTER_URL="https://updates.jenkins.io/current/update-center.actual.json"

# Fetch latest plugin metadata, extract '.plugins' object as JSON into update-center.json
curl -s "$UPDATE_CENTER_URL" | jq '.plugins' > update-center.json
if [ $? -ne 0 ]; then
    echo "Failed to download or parse update-center JSON"
    exit 1
fi

# Loop through plugins.txt, expected format: pluginId:expectedVersion per line
while IFS=: read -r plugin expected_version; do
    if [ -z "$plugin" ] || [ -z "$expected_version" ]; then
        echo "Skipping invalid line: $plugin:$expected_version"
        continue
    fi

    # Get installed version of the plugin via Jenkins CLI
    installed_version=$($CLI -auth "$AUTH" list-plugins | awk -v p="$plugin" '$1 == p {print $2}')
    if [ $? -ne 0 ]; then
        echo "Failed to query installed plugins"
        exit 2
    fi

    # Get latest available plugin version from update-center.json
    latest_version=$(jq -r --arg p "$plugin" '.[$p].version // empty' update-center.json)
    if [ -z "$latest_version" ]; then
        echo "Warning: Latest version info missing for $plugin"
    fi

    # Output based on comparison
    if [ -z "$installed_version" ]; then
        echo "MISSING: $plugin (expected $expected_version)"
    elif [ "$installed_version" != "$expected_version" ]; then
        echo "VERSION MISMATCH: $plugin installed=$installed_version expected=$expected_version latest=$latest_version"
    else
        echo "OK: $plugin version $installed_version"
    fi
done < plugins.txt
