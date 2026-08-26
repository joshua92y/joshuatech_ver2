# approval-review hook (UserPromptSubmit).
# If the user's prompt looks like an approval, instruct the agent to run /approval-review first.
# Spec D15: the keyword set is intentionally broad. Fail-open: any error -> exit 0, no output.
try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $data = $raw | ConvertFrom-Json
    $prompt = ''
    foreach ($k in @('prompt', 'userPrompt', 'message')) {
        if ($data.PSObject.Properties[$k] -and $data.$k) { $prompt = [string]$data.$k; break }
    }
    if (-not $prompt) { exit 0 }
    $pattern = '승인|approve|approved|lgtm|진행해'
    if ($prompt -notmatch $pattern) { exit 0 }
    $msg = @"
[APPROVAL REVIEW HOOK]
The user's message contains an approval keyword. If this is an approval of the active feature's spec, plan, or tasks:
1. Do NOT mark anything Approved yet.
2. Run the /approval-review skill first (parallel boundary reviews: security, tenant-data, operability, trends, spec-consistency).
3. Show the review summary and ask the user to confirm; only then set the spec Status to Approved.
If the message is not an approval of feature artifacts (it merely mentions approvals), ignore this notice.
"@
    @{ systemMessage = $msg } | ConvertTo-Json -Compress | Write-Output
    exit 0
} catch {
    exit 0
}
