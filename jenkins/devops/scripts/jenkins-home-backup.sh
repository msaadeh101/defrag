#!/bin/bash

# Set the AWS CLI profile to use for S3 operations
# This profile must have permissions for 's3:PutObject'
export AWS_PROFILE=jenkins-backup

S3_BUCKET="jenkins-backups"
JENKINS_HOME="/var/lib/jenkins"
TMP_DIR="/tmp"

# Generate a timestamp for the backup file and S3 folder
TS=$(date +%F)
BACKUP_FILE="${TMP_DIR}/jenkins-home-${TS}.tar.gz"

# Function to handle errors
handle_error() {
  local exit_code=$?
  echo "Error: The last command failed with exit code $exit_code." >&2
  # Clean up the temporary backup file if it exists
  if [[ -f "${BACKUP_FILE}" ]]; then
    echo "Cleaning up temporary backup file: ${BACKUP_FILE}"
    rm -f "${BACKUP_FILE}"
  fi
  exit 1
}

# Trap errors and call the error handling function
trap handle_error ERR

echo "Starting Jenkins home directory backup..."

echo "Creating archive..."
tar --exclude='workspace' --exclude='logs' -czf "${BACKUP_FILE}" "${JENKINS_HOME}"

# Check if the archive was created successfully
if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "Error: The tar archive was not created."
  exit 1
fi

echo "Archive created successfully: ${BACKUP_FILE}"

# Upload the backup file to S3 with a unique folder name
echo "Uploading backup to s3://${S3_BUCKET}/${TS}/"
aws s3 cp "${BACKUP_FILE}" "s3://${S3_BUCKET}/${TS}/"

echo "Backup uploaded successfully."

# Remove the local temporary file
echo "Cleaning up temporary local file..."
rm -f "${BACKUP_FILE}"

echo "Backup script finished successfully."