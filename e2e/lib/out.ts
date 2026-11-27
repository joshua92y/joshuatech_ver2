// e2e/lib/out.ts — 출력 통로(설계 D5 경계 · D10 ⑤ · r2 — V-2). e2e 코드가 표준 출력에 내는 줄은 모두 여기를 지난다.
// 미리 정한 꼴의 줄만 받는다: 단계 줄 · INFO 줄 · 멈춤 줄([접두]) · 요약 줄. 기계 판독 부분(첫 ' — ' 앞)은 인쇄 가능한 ASCII여야 하고,
// 줄바꿈 · 제어 문자는 어디에도 들 수 없다. 거부할 때 줄 내용을 오류 메시지에 싣지 않는다(값이 섞였을 수 있다).

export const SEP = ' — ';

export const STOP_PREFIXES = ['gate', 'product', 'env', 'decision', 'guard', 'state'] as const;
export type StopPrefix = (typeof STOP_PREFIXES)[number];
export type Verdict = 'PASS' | 'FAIL';

const PRINTABLE_ASCII = /^[\x20-\x7e]+$/;
const CONTROL = /[\x00-\x1f\x7f]/;
const SHAPES: readonly RegExp[] = [
  /^T0\d\d [a-z][a-z0-9-]* (PASS|FAIL)( [\x20-\x7e]+)?$/, // 단계 줄
  /^INFO [\x20-\x7e]+$/, // INFO 줄
  /^\[(gate|product|env|decision|guard|state)\] [\x20-\x7e]+$/, // 멈춤 줄
  /^SUMMARY [\x20-\x7e]+$/, // 요약 줄
];

function reject(reason: string): never {
  throw new Error(`out: line rejected (${reason})`);
}

export function checkLine(line: string): string {
  if (typeof line !== 'string') reject('type');
  if (line.includes('\n') || line.includes('\r')) reject('newline');
  const at = line.indexOf(SEP);
  const machine = at === -1 ? line : line.slice(0, at);
  if (!PRINTABLE_ASCII.test(machine)) reject('machine part not printable ASCII');
  if (!SHAPES.some((re) => re.test(machine))) reject('shape');
  if (at !== -1) {
    const note = line.slice(at + SEP.length);
    if (note.trim().length === 0) reject('empty note');
    if (CONTROL.test(note)) reject('control character in note');
  }
  return line;
}

function withNote(machine: string, note?: string): string {
  return checkLine(note === undefined ? machine : machine + SEP + note);
}

export function formatStep(task: string, step: string, verdict: Verdict, reason?: string, note?: string): string {
  const machine = [task, step, verdict, reason].filter((s) => s !== undefined && s !== '').join(' ');
  return withNote(machine, note);
}

export function formatInfo(text: string, note?: string): string {
  return withNote(`INFO ${text}`, note);
}

export function formatStop(prefix: StopPrefix, code: string, note?: string): string {
  return withNote(`[${prefix}] ${code}`, note);
}

export function formatSummary(text: string, note?: string): string {
  return withNote(`SUMMARY ${text}`, note);
}

function defaultWrite(s: string): void {
  process.stdout.write(s);
}

export function emit(line: string, write: (s: string) => void = defaultWrite): void {
  write(checkLine(line) + '\n');
}

export function emitStep(task: string, step: string, verdict: Verdict, reason?: string, note?: string): string {
  const line = formatStep(task, step, verdict, reason, note);
  emit(line);
  return line;
}

export function emitInfo(text: string, note?: string): string {
  const line = formatInfo(text, note);
  emit(line);
  return line;
}

export function emitStop(prefix: StopPrefix, code: string, note?: string): string {
  const line = formatStop(prefix, code, note);
  emit(line);
  return line;
}

export function emitSummary(text: string, note?: string): string {
  const line = formatSummary(text, note);
  emit(line);
  return line;
}
