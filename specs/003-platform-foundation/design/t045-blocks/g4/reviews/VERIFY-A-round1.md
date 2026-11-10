CHANGES_REQUESTED

The two blocks behave correctly in the 67 scenarios, my 8 extra scenarios, and every execution mode I tested, with one gap: when both the ssh and oci probes fail, the single word `no-oci` still allows the pod delete (finding 5). The harness and mutant suite, however, fail to catch 7 lock-leading mutants, and one mutant described in NOTES does not test what it claims. The changes I am requesting are mostly to the harness, lint and NOTES, not to block logic.

## Task items (1)–(4)

**(1) Structure.** `g4-adopt.ps1` has 0 parse errors, 1 top-level statement, 0 blank lines, 0 CR bytes, tail `0A 7D 0A`, no BOM, 479 lines. `g4-restore.ps1` has the same values at 190 lines. Tabs, trailing whitespace, smart quotes, NBSP/ZWSP and em-dashes in code are all 0. The only global variable touched is `$global:LASTEXITCODE`.

**(2) Reproducing NOTES.** `harness-g4.ps1` gives `PASS 67 / 67 (lint 실패 0)`, which matches NOTES. `mutants-g4.ps1` gives 53/53 CAUGHT in 285 s, which also matches. The M18 entry in the NOTES table is wrong (finding 8).

**(3) My new mutants.** 39 mutants, none overlapping M01–M53: 19 CAUGHT, 20 ESCAPED, 0 anchor errors.
- Caught: A01, A02, A04–A10b, A14, A20, A22, A26, A30, B04, B05, B06, B09.
- Escaped: A03, A11, A12, A13, A15, B01, B03 (all lock-leading), plus A16, A17, A18, A19, A28, A31, A32, A33, A34, A37, A38, B02, B11.

**(4) Execution modes.**
- File execution, `[ScriptBlock]::Create`, stdin (`-Command -`) and dot-source all behave the same across 6 scenarios. No secrets leaked and no session variables were left behind. `$ErrorActionPreference` is preserved.
- Under `-NonInteractive`, both blocks fail closed in both file and stdin modes: a Read-Host error, 0 changes, the summary printed, and rc=1.
- Three stdin quirks are listed as finding 11.

## Findings

Line numbers for the blocks refer to `scratchpad\t045-g4-blocks\g4-adopt.ps1` and `g4-restore.ps1`.

**1. [High · harness] A mutating kubectl call inside an allowed helper goes undetected — `harness-g4.ps1:305-311`, `:164-192`.**
- Mutant A12 puts `kubectl scale deploy/cloudflared --replicas=0` inside `$klog`. Result: lint clean, 67/67 PASS.
- The lint restricts verbs only for `$kq`.
- The mock records only `apply` and `delete` in `$global:Mut`; any other verb silently returns exit 1.
- This breaks the NOTES §2 claim that requirement (h) is guaranteed four ways.
- Suggestion: add a per-helper verb whitelist (`$kq` get/auth, `$klog` logs, `$kdel` delete pod). Have the mock record every verb other than get/auth/logs in `Mut` with its full argv.

**2. [High · harness] A mutation path outside kubectl is not checked — `g4-adopt.ps1:146`, `:420`.**
- Mutant A13 changes the ssh remote command to `sudo k3s kubectl … rollout restart …; hostname`. It escaped.
- Neither the lint nor the mock looks at ssh or oci arguments.
- Suggestion: restrict ssh remote commands to exactly `cut -c1-8 /proc/sys/kernel/random/boot_id` and `hostname`. Require `-n` and `BatchMode=yes`. Pin the oci arguments. Replace the blacklist of output cmdlets with a whitelist of command names; the adopt block calls 15 commands.

**3. [High · harness] The mock delete records only one name and ignores flags — `harness-g4.ps1:179-191`.**
- Mutant A11 runs `delete pod $pod $survivor`. The argv carried both pod names, but the Mut log showed one entry, so it passed. Extra scenario X4m confirms this.
- Mutant A37 adds `--force --grace-period=0` and also escaped.
- Lint L-C checks only that required flags are present.
- Suggestion: have the mock log all positional names plus selector and force flags. Have the lint match the `$kdel` kubectl elements exactly, one by one.

**4. [High · harness] Four lock-leading behaviours have no scenario.**
- Scenarios are missing for all four:
  - **Value changes during polling while the ES never syncs.** Mutant A03 removes the value check from the watch loop (`g4-adopt.ps1:262`). The original block throws `대기 중 터널 값이 바뀌었다` with recovery guidance. The mutant instead times out after 15 minutes with `아무것도 바꾸지 않았다` and no guidance (X1/X1m).
  - **Resume when the value is already overwritten.** Mutant A15 replaces the operator's preHash with the live hash. The original block stops. The mutant reports `OK 값 불변` and goes on to delete a pod (X5/X5m).
  - **Restore re-read after the write.** Mutant B01 removes the post-write value check (`g4-restore.ps1:161`). The original block throws when the value is overwritten again right after apply. The mutant reports `OK 복구 완료` (X6/X6m). Mutant B02, the UID check at `:164`, has no scenario either.
  - **Restore flags.** Mutant B03 removes `--force-conflicts` (`g4-restore.ps1:85`). Live, this makes the emergency restore fail when it conflicts with ESO's field manager.
- G4-06 expects only the substring `터널 값이 바뀌었다`, which matches both the watch-loop message and the step 3 message, so it cannot tell them apart.
- Suggestion: add X1, X5, X6 and the UID variant as scenarios. Make the G4-06 expectation `대기 중 터널 값`. Add `--force-conflicts` and `--field-manager=` to the required flags in L-C.

**5. [Medium · block] With both break-glass probes failed, one word still allows the drill — `g4-adopt.ps1:170-173`.**
- X3: ssh and oci both fail, and typing `no-oci` alone runs through to the pod deletion.
- The word does not make the operator acknowledge that the window A ssh session was never verified.
- Suggestion: use a separate word such as `no-breakglass` when both fail. Alternatively, allow the adoption judgement but refuse step 4 (the only mutating step) unless at least one break-glass path is verified.

**6. [Medium · block] Rerunning after a finished drill misleads the operator, and the K8S-04 SKIP cannot be reached with honest input — `g4-adopt.ps1:188`, `:325-326`, `:347-350`.**
- X2: entering the recorded pre-drill signature, as the prompt asks, throws `파드가 바뀌었다 … 인수 과정에서 커넥터가 교체·재시작됐다`. The real cause is the previous run's own drill.
- G4-24 passes only because it feeds a post-drill signature that the block never prints.
- The outcome is safe (0 deletes), but the wording can wrongly push the operator into recovery.
- Suggestion: if one pod's signature is unchanged and the other started Ready after the ES was created, report `이전 실행의 드릴 결과` and SKIP. Or print `드릴 후 파드서명` in the summary.

**7. [Medium · harness] Convention regressions that escape.**
- A16 removes `FlushInputBuffer` from `$stop` (safety rule 1).
- A28 and B11 remove the clipboard clear after a secret read.
- A31 turns a line in `finally` into success-stream output; A32 moves cleanup after the prints (rule 5).
- A33 removes `$ErrorActionPreference='Stop'`; A34 removes `$PSNativeCommandUseErrorActionPreference=$false`.
- A17 removes `--request-timeout` from `$kq`, which means an indefinite hang if the tunnel stalls.
- A18 removes the cluster identity check; A19 removes the pre-merge pod Ready check.
- A38 prints the first 16 characters of the value. The leak check only tests for the full string.
- Suggestion: add AST lint rules for each.
  - Require `FlushInputBuffer` before any `Read-Host` in the same scriptblock.
  - Require the first statement of `finally` to be `Remove-Variable`, and forbid bare expressions there.
  - Pin the first two statements of the block.
  - Require `--request-timeout=` in `$kq`.
  - Assert `ClipValues.Count ≥ 1` after any secure read.
  - Add 12-character prefix and suffix windows to the leak check.
  - Add a wrong-cluster scenario and a pre-merge NotReady-pod scenario.

**8. [Medium · NOTES/mutants] M18 does not mutate what it says — `mutants-g4.ps1:33`.**
- Its anchor is `occ=2`, which hits L323 (the nopods warning branch in step 3). The intended drill guard is at L337; the anchor string occurs at L189, 323, 328 and 337.
- The actual failure is `파드가 바뀌었다(전= / 후=…)`. It never gets as far as testing "delete even in a nopods run".
- My A20 mutates the real L337 guard. It is caught by G4-02e, but only because the input queue has no `drill`.
- Suggestion: change to `occ=4` or use a unique anchor. Add `drill` to the G4-02e inputs and assert the Mut log stays empty. Correct the M18 row in NOTES §5.

**9. [Low · block] At stdin EOF, `$ask` fails with an unhelpful error — `g4-adopt.ps1:68-70`, `g4-restore.ps1:49-51`.**
- The real `Read-Host` returns `$null` at EOF, and `[string]` of it is still `$null`.
- The `.Trim()` call then raises `null 값 식에서 메서드를 호출할 수 없습니다`.
- This is fail-closed with 0 changes; only the message is poor.
- Suggestion: `if ($null -eq $v) { throw '입력 스트림이 닫혔다 — 대화형 콘솔에서 파일로 실행' }`.

**10. [Low · block] A failed clipboard clear is silent — `g4-adopt.ps1:75`.**
- The adopt `finally` has no clipboard clear at all.
- If `Set-Clipboard` inside `$readSecret` fails, the `catch { }` swallows it and the token stays on the clipboard with no notice.
- Suggestion: emit `Write-Warning` on failure, and add one more clear to the adopt `finally`.

**11. [Info · execution modes] Stdin quirks.**
- `pwsh -Command -` runs a multi-line `& { … }` only if an extra newline follows the final `}`.
  - Feeding the file bytes unchanged (ending `}` plus one LF, per rule 6) executes nothing and exits 0.
  - PowerShell's own pipe appends a newline, so that path does run.
- `Read-Host -AsSecureString` reads the console even when stdin is redirected.
  - A pipe cannot satisfy it.
  - With no console it waits forever.
  - Under `-NonInteractive` it errors and stops.
- "Answers" appended after the block on stdin are parsed as script, so they cannot pass a stop point.
- Suggestion: add one line to the header saying stdin execution is unsupported and the block must be run as a file.
- Still unverified: pasting the block through PSReadLine, real native kubectl argv quoting, and `$PSNativeCommandUseErrorActionPreference` with a real native command. None of these can be reproduced without a real console and binary.

## Verification artifacts

All are read-only with respect to the four deliverables and the repository, and have 0 CR bytes. They are in `C:\Users\2401\AppData\Local\Temp\claude\d--code-joshuatech-ver2\df87ded7-ec45-4ac5-a67b-9b974d5bfd59\scratchpad\t045-g4-blocks\_verifier-a\`:
- `mutants-a.ps1` — the 39 mutants, parallel run. Results are in `mutants-a.out.txt` and `mutants-a.result.json`.
- `extra-a.ps1` — scenarios X1–X6. Takes `-MutRoot <copy root from mutants-a.ps1 -KeepDirs>`.
- `modes-a.ps1` — file, ScriptBlock, stdin and `-NonInteractive` runs.
- `dotsource-a.ps1` — dot-source equivalence and variable-leak check.
- `prelude.generated.ps1` — the harness mocks, extracted.

No real kubectl, ssh, oci or vault was called: all runs used mock functions, and child processes ran with PATH narrowed to pwsh and System32 and KUBECONFIG pointing to a nonexistent path.