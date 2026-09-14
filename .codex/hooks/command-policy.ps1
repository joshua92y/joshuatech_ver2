# Codex PreToolUse policy for destructive shell commands.
# The command text is parsed as data only; it is never evaluated or executed.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Denial([string]$Reason) {
    $payload = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    }
    [Console]::Out.WriteLine(($payload | ConvertTo-Json -Compress -Depth 5))
}

function Get-ExecutableLeaf([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $leaf = @($Value -split '[\\/]')[-1]
    if ($leaf.EndsWith('.exe', [StringComparison]::OrdinalIgnoreCase)) {
        $leaf = $leaf.Substring(0, $leaf.Length - 4)
    }
    return $leaf.ToLowerInvariant()
}

function Get-CommandWords([System.Management.Automation.Language.CommandAst]$CommandAst) {
    $words = [Collections.Generic.List[object]]::new()
    foreach ($element in $CommandAst.CommandElements) {
        $known = $true
        $value = $null
        if ($element -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $value = [string]$element.Value
        } elseif ($element -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and
            @($element.NestedExpressions).Count -eq 0) {
            $value = [string]$element.Value
        } elseif ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
            $value = [string]$element.Extent.Text
        } else {
            $known = $false
        }

        [void]$words.Add([pscustomobject]@{
            Known = $known
            Value = $value
            Raw = [string]$element.Extent.Text
        })
    }
    return @($words)
}

function Get-ConstantTail([object[]]$Words, [int]$StartIndex) {
    if ($StartIndex -ge $Words.Count) {
        return [pscustomobject]@{ Valid = $false; Text = '' }
    }

    $tail = @($Words[$StartIndex..($Words.Count - 1)])
    if (@($tail | Where-Object { -not $_.Known }).Count -gt 0) {
        return [pscustomobject]@{ Valid = $false; Text = '' }
    }

    if ($tail.Count -eq 1) {
        return [pscustomobject]@{ Valid = $true; Text = [string]$tail[0].Value }
    }
    return [pscustomobject]@{ Valid = $true; Text = (($tail | ForEach-Object { $_.Raw }) -join ' ') }
}

function Find-WrapperCommandStart([object[]]$Words, [int]$StartIndex, [string]$Kind) {
    $valueOptions = if ($Kind -eq 'sudo') {
        @('-u', '--user', '-g', '--group', '-h', '--host', '-c', '--chdir', '-r', '--chroot', '-t', '--command-timeout', '-p', '--prompt')
    } elseif ($Kind -eq 'env') {
        @('-u', '--unset', '-c', '--chdir', '-s', '--split-string')
    } else {
        @()
    }

    $index = $StartIndex
    while ($index -lt $Words.Count) {
        if (-not $Words[$index].Known) { return -1 }
        $value = [string]$Words[$index].Value
        $lower = $value.ToLowerInvariant()
        if ($value -ceq '--') { return $index + 1 }
        if ($Kind -eq 'env' -and $value -match '^[A-Za-z_][A-Za-z0-9_]*=') {
            $index++
            continue
        }
        if ($value.StartsWith('-')) {
            if ($valueOptions -contains $lower -and $index + 1 -lt $Words.Count) {
                $index += 2
            } else {
                $index++
            }
            continue
        }
        return $index
    }
    return -1
}

function Find-GitSubcommand([object[]]$Words) {
    $valueOptions = @('-c', '-C', '--exec-path', '--git-dir', '--work-tree', '--namespace', '--config-env')
    $index = 1
    while ($index -lt $Words.Count) {
        if (-not $Words[$index].Known) { return -1 }
        $value = [string]$Words[$index].Value
        if ($value -ceq '--') { return $(if ($index + 1 -lt $Words.Count) { $index + 1 } else { -1 }) }
        if ($value.StartsWith('-')) {
            $takesValue = $valueOptions -ccontains $value
            if ($takesValue -and $index + 1 -lt $Words.Count) {
                $index += 2
            } else {
                $index++
            }
            continue
        }
        return $index
    }
    return -1
}

function Find-DockerCommand([object[]]$Words) {
    $valueOptions = @('-c', '--config', '--context', '-h', '--host', '-l', '--log-level')
    $index = 1
    while ($index -lt $Words.Count) {
        if (-not $Words[$index].Known) { return -1 }
        $value = [string]$Words[$index].Value
        if ($value -ceq '--') { return $(if ($index + 1 -lt $Words.Count) { $index + 1 } else { -1 }) }
        if ($value.StartsWith('-')) {
            $lower = $value.ToLowerInvariant()
            if ($valueOptions -contains $lower -and $index + 1 -lt $Words.Count) {
                $index += 2
            } else {
                $index++
            }
            continue
        }
        return $index
    }
    return -1
}

function Test-CommandText([string]$CommandText, [int]$Depth = 0) {
    if ($Depth -gt 8) { return 'Nested shell command depth exceeds the repository policy limit.' }
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return 'Bash command is missing or empty.' }

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $CommandText,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if (@($parseErrors).Count -gt 0) { return 'Bash command could not be parsed safely.' }

    $commands = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst]
    }, $true))

    foreach ($commandAst in $commands) {
        $words = @(Get-CommandWords $commandAst)
        if ($words.Count -eq 0) { continue }

        $assignmentCount = 0
        while ($assignmentCount -lt $words.Count -and $words[$assignmentCount].Known -and
            ([string]$words[$assignmentCount].Value) -match '^[A-Za-z_][A-Za-z0-9_]*=') {
            $assignmentCount++
        }
        if ($assignmentCount -gt 0) {
            if ($assignmentCount -ge $words.Count) { continue }
            $tail = Get-ConstantTail $words $assignmentCount
            if (-not $tail.Valid) { return 'A command after POSIX environment assignments could not be inspected safely.' }
            $nestedReason = Test-CommandText $tail.Text ($Depth + 1)
            if ($nestedReason) { return $nestedReason }
            continue
        }

        if (-not $words[0].Known) {
            return 'Dynamic command executable invocation could not be inspected safely.'
        }
        $executable = Get-ExecutableLeaf ([string]$words[0].Value)

        if ($executable -eq 'git') {
            $subcommandIndex = Find-GitSubcommand $words
            if ($subcommandIndex -lt 0 -or -not $words[$subcommandIndex].Known) { continue }
            $subcommand = ([string]$words[$subcommandIndex].Value).ToLowerInvariant()
            $arguments = if ($subcommandIndex + 1 -lt $words.Count) {
                @($words[($subcommandIndex + 1)..($words.Count - 1)])
            } else { @() }
            if (@($arguments | Where-Object { -not $_.Known }).Count -gt 0 -and
                $subcommand -in @('reset', 'push', 'clean')) {
                return "Git $subcommand arguments could not be inspected safely."
            }
            $argumentValues = @($arguments | ForEach-Object { [string]$_.Value })

            if ($subcommand -eq 'reset' -and @($argumentValues | Where-Object {
                $_ -ceq '--hard' -or $_.StartsWith('--hard=', [StringComparison]::Ordinal)
            }).Count -gt 0) {
                return 'Hard git reset is forbidden because it can discard repository work.'
            }
            if ($subcommand -eq 'push' -and @($argumentValues | Where-Object {
                $_ -ceq '-f' -or $_.StartsWith('--force', [StringComparison]::Ordinal) -or
                $_.StartsWith('+', [StringComparison]::Ordinal)
            }).Count -gt 0) {
                return 'Force push is forbidden because it can rewrite shared history.'
            }
            if ($subcommand -eq 'clean' -and @($argumentValues | Where-Object {
                $_ -ceq '--force' -or $_.StartsWith('--force=', [StringComparison]::Ordinal) -or
                ($_ -match '^-[^-]*[fd]')
            }).Count -gt 0) {
                return 'Destructive git clean is forbidden because it can delete untracked work.'
            }
            continue
        }

        if ($executable -eq 'docker') {
            $dockerIndex = Find-DockerCommand $words
            if ($dockerIndex -ge 0 -and $dockerIndex + 1 -lt $words.Count -and
                $words[$dockerIndex].Known -and $words[$dockerIndex + 1].Known) {
                $scope = ([string]$words[$dockerIndex].Value).ToLowerInvariant()
                $operation = ([string]$words[$dockerIndex + 1].Value).ToLowerInvariant()
                if ($scope -in @('system', 'image', 'container', 'volume', 'network', 'builder', 'buildx') -and
                    $operation -eq 'prune') {
                    return 'Docker prune is forbidden because it can delete shared resources.'
                }
            }
            continue
        }

        if ($executable -eq 'rm') {
            $rmArguments = if ($words.Count -gt 1) { @($words[1..($words.Count - 1)]) } else { @() }
            if (@($rmArguments | Where-Object { -not $_.Known }).Count -gt 0) {
                return 'rm arguments could not be inspected safely.'
            }
            if (@($rmArguments | Where-Object {
                $value = [string]$_.Value
                $value -ceq '--recursive' -or $value.StartsWith('--recursive=', [StringComparison]::Ordinal) -or
                ($value -match '^-[^-]*[rR]')
            }).Count -gt 0) {
                return 'Recursive rm is forbidden because it can irreversibly delete filesystem trees.'
            }
            continue
        }

        if ($executable -in @('remove-item', 'del', 'erase', 'rd', 'ri', 'rmdir')) {
            $removeArguments = if ($words.Count -gt 1) { @($words[1..($words.Count - 1)]) } else { @() }
            if (@($removeArguments | Where-Object { -not $_.Known }).Count -gt 0) {
                return 'Remove-Item arguments could not be inspected safely.'
            }
            if (@($removeArguments | Where-Object {
                $value = [string]$_.Value
                $parameterName = @($value -split ':', 2)[0]
                $parameterName.Length -ge 2 -and
                    '-Recurse'.StartsWith($parameterName, [StringComparison]::OrdinalIgnoreCase)
            }).Count -gt 0) {
                return 'Recursive Remove-Item is forbidden because it can irreversibly delete filesystem trees.'
            }
            continue
        }

        if ($executable -in @('eval', 'invoke-expression', 'iex')) {
            return "Dynamic evaluation through $executable could not be inspected safely."
        }

        if ($executable -in @('sudo', 'env', 'command')) {
            $start = Find-WrapperCommandStart $words 1 $executable
            if ($start -lt 0 -or $start -ge $words.Count) {
                return "The $executable wrapper command could not be inspected safely."
            }
            if ($executable -eq 'sudo' -and $words[$start].Known -and
                (Get-ExecutableLeaf ([string]$words[$start].Value)) -eq 'rm') {
                return 'Privileged rm is forbidden by repository policy.'
            }
            $tail = Get-ConstantTail $words $start
            if (-not $tail.Valid) { return "The $executable wrapper command could not be inspected safely." }
            $nestedReason = Test-CommandText $tail.Text ($Depth + 1)
            if ($nestedReason) { return $nestedReason }
            continue
        }

        if ($executable -in @('pwsh', 'powershell')) {
            $encodedIndex = -1
            $commandIndex = -1
            for ($index = 1; $index -lt $words.Count; $index++) {
                if (-not $words[$index].Known) { continue }
                $option = ([string]$words[$index].Value).ToLowerInvariant()
                if ($option.StartsWith('/')) { $option = '-' + $option.Substring(1) }
                if ($option -eq '-ec' -or
                    ($option.Length -ge 2 -and '-encodedcommand'.StartsWith($option, [StringComparison]::OrdinalIgnoreCase))) {
                    $encodedIndex = $index
                    break
                }
                if ($option.Length -ge 2 -and '-command'.StartsWith($option, [StringComparison]::OrdinalIgnoreCase)) {
                    $commandIndex = $index
                    break
                }
            }
            if ($encodedIndex -ge 0) {
                if ($encodedIndex + 1 -ge $words.Count -or -not $words[$encodedIndex + 1].Known) {
                    return 'PowerShell EncodedCommand payload is missing or ambiguous.'
                }
                try {
                    $bytes = [Convert]::FromBase64String([string]$words[$encodedIndex + 1].Value)
                    $encoding = [Text.UnicodeEncoding]::new($false, $false, $true)
                    $decoded = $encoding.GetString($bytes)
                } catch {
                    return 'PowerShell EncodedCommand payload is invalid.'
                }
                $nestedReason = Test-CommandText $decoded ($Depth + 1)
                if ($nestedReason) { return $nestedReason }
            } elseif ($commandIndex -ge 0) {
                $tail = Get-ConstantTail $words ($commandIndex + 1)
                if (-not $tail.Valid) { return 'PowerShell Command payload is missing or ambiguous.' }
                $nestedReason = Test-CommandText $tail.Text ($Depth + 1)
                if ($nestedReason) { return $nestedReason }
            }
            continue
        }

        if ($executable -eq 'cmd') {
            $commandIndex = -1
            for ($index = 1; $index -lt $words.Count; $index++) {
                if ($words[$index].Known -and ([string]$words[$index].Value).ToLowerInvariant() -in @('/c', '/k')) {
                    $commandIndex = $index
                    break
                }
            }
            if ($commandIndex -ge 0) {
                $tail = Get-ConstantTail $words ($commandIndex + 1)
                if (-not $tail.Valid) { return 'cmd command payload is missing or ambiguous.' }
                $nestedReason = Test-CommandText $tail.Text ($Depth + 1)
                if ($nestedReason) { return $nestedReason }
            }
            continue
        }

        if ($executable -in @('bash', 'sh', 'zsh')) {
            $commandIndex = -1
            for ($index = 1; $index -lt $words.Count; $index++) {
                if (-not $words[$index].Known) { continue }
                $option = [string]$words[$index].Value
                if ($option -match '^-[^-]*c[^-]*$') {
                    $commandIndex = $index
                    break
                }
            }
            if ($commandIndex -ge 0) {
                $tail = Get-ConstantTail $words ($commandIndex + 1)
                if (-not $tail.Valid) { return "$executable command payload is missing or ambiguous." }
                $nestedReason = Test-CommandText $tail.Text ($Depth + 1)
                if ($nestedReason) { return $nestedReason }
            }
        }
    }
    return $null
}

try {
    $rawInput = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        Write-Denial 'Hook input is missing or empty.'
        exit 0
    }

    try {
        $data = $rawInput | ConvertFrom-Json -Depth 30
    } catch {
        Write-Denial 'Hook input is not valid JSON.'
        exit 0
    }

    $eventProperty = $data.PSObject.Properties['hook_event_name']
    $toolProperty = $data.PSObject.Properties['tool_name']
    if ($null -eq $eventProperty -or $null -eq $toolProperty) {
        Write-Denial 'Hook input is missing its event or tool name.'
        exit 0
    }
    if ($eventProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$eventProperty.Value)) {
        Write-Denial 'Hook event name must be a non-empty string.'
        exit 0
    }
    if ($toolProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$toolProperty.Value)) {
        Write-Denial 'Hook tool name must be a non-empty string.'
        exit 0
    }
    if ([string]$eventProperty.Value -cne 'PreToolUse' -or [string]$toolProperty.Value -cne 'Bash') {
        exit 0
    }

    $toolInputProperty = $data.PSObject.Properties['tool_input']
    $commandProperty = if ($null -ne $toolInputProperty -and $null -ne $toolInputProperty.Value) {
        $toolInputProperty.Value.PSObject.Properties['command']
    } else { $null }
    if ($null -eq $commandProperty -or $commandProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$commandProperty.Value)) {
        Write-Denial 'Bash payload must contain a non-empty string command.'
        exit 0
    }

    $reason = Test-CommandText ([string]$commandProperty.Value)
    if ($reason) { Write-Denial $reason }
} catch {
    Write-Denial 'The command policy could not inspect this Bash payload safely.'
}

exit 0
