// Keep generated source documentation concise and English.
// Local design extraction notes are intentionally not emitted into app code.
export function generatedComments(source) {
  return source
    .split('\n')
    .filter((line) => !/^\s*\/\/[^\n]*[\p{Script=Hangul}]/u.test(line))
    .map((line) => line.replace(/;\s*\/\/[^\n]*[\p{Script=Hangul}][^\n]*$/u, ';'))
    .join('\n');
}
