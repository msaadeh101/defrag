def call(Map config) {
    def channel = config.channel ?: '#ci-cd'
    def message = config.message ?: 'Jenkins Pipeline Notification'
    def color = getColorForStatus(config.status ?: 'info')
    def webhook = config.webhook ?: env.SLACK_WEBHOOK_URL
    
    if (!webhook) {
        echo "Warning: No Slack webhook configured, skipping notification"
        return
    }
    
    def payload = [
        channel: channel,
        username: 'Jenkins',
        icon_emoji: ':jenkins:',
        attachments: [[
            color: color,
            title: "${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
            text: message,
            fields: [
                [title: 'Status', value: config.status ?: 'info', short: true],
                [title: 'Branch', value: env.BRANCH_NAME ?: 'N/A', short: true],
                [title: 'Duration', value: getBuildDuration(), short: true]
            ],
            footer: 'Jenkins',
            footer_icon: 'https://jenkins.io/images/logos/jenkins/jenkins.png',
            ts: System.currentTimeMillis() / 1000
        ]]
    ]
    
    def payloadJson = writeJSON returnText: true, json: payload
    
    sh """
        curl -X POST -H 'Content-type: application/json' \
        --data '${payloadJson}' \
        ${webhook}
    """
}

// Convenience methods for different notification types
def success(String message, String channel = null) {
    call([
        status: 'success',
        message: message,
        channel: channel
    ])
}

def failure(String message, String channel = null) {
    call([
        status: 'failure',
        message: message,
        channel: channel
    ])
}

def warning(String message, String channel = null) {
    call([
        status: 'warning',
        message: message,
        channel: channel
    ])
}

private def getColorForStatus(String status) {
    switch(status.toLowerCase()) {
        case 'success': return 'good'
        case 'failure': return 'danger'
        case 'warning': return 'warning'
        default: return '#439FE0'
    }
}

private def getBuildDuration() {
    def duration = currentBuild.duration
    if (duration == null) return 'In Progress'
    
    def minutes = Math.floor(duration / 60000)
    def seconds = Math.floor((duration % 60000) / 1000)
    
    return "${minutes}m ${seconds}s"
}