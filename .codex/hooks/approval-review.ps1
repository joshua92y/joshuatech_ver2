# Codex UserPromptSubmit hook for the approval-review workflow.
# Approval-like prompts receive model-visible context; all parse failures fail open.
try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    [Console]::OutputEncoding = [Text.Encoding]::UTF8

    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

    $data = $raw | ConvertFrom-Json
    if ([string]$data.hook_event_name -cne 'UserPromptSubmit') { exit 0 }

    $prompt = [string]$data.prompt
    if ([string]::IsNullOrWhiteSpace($prompt)) { exit 0 }
    if ($prompt -notmatch '승인|진행해|(?<![A-Za-z0-9_])(?:approve|approved|lgtm)(?![A-Za-z0-9_])') { exit 0 }

    $message = @'
[APPROVAL REVIEW HOOK]
The user's message contains an approval keyword. If this approves the active feature's spec, plan, or tasks:
1. Do not mark the artifact Approved yet.
2. Invoke the $approval-review skill first for the required parallel boundary reviews.
3. Show the review summary and ask the user to confirm; only then set the artifact Status to Approved.
If the prompt only mentions approval and does not approve a feature artifact, ignore this notice.
'@

    [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName = 'UserPromptSubmit'
            additionalContext = $message
        }
    } | ConvertTo-Json -Compress -Depth 5 | Write-Output
    exit 0
} catch {
    exit 0
}
