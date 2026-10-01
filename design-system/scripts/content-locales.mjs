// Translations contain only copy. Asset paths, IDs, and layout data stay in the
// source catalog. Validate all paths and placeholders before generating Dart.
export function translateContent(source, messages, { validate = false } = {}) {
  const used = new Set();
  const placeholders = (text) => [...text.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort().join(',');
  function visit(value, path = '') {
    if (Array.isArray(value)) return value.map((item, i) => visit(item, `${path}.${i}`));
    if (value !== null && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key, item]) => [
        key,
        key.startsWith('$') || key === 'figmaName' ? item : visit(item, path ? `${path}.${key}` : key),
      ]));
    }
    if (Object.hasOwn(messages, path)) {
      const translation = messages[path];
      if (typeof value !== 'string' || typeof translation !== 'string' || !translation.trim()) {
        throw new Error(`Invalid translation at ${path}`);
      }
      if (/[가-힣]/.test(translation) || placeholders(value) !== placeholders(translation)) {
        throw new Error(`Untranslated text or mismatched placeholders at ${path}`);
      }
      used.add(path);
      return translation;
    }
    if (validate && typeof value === 'string' && /[가-힣]/.test(value)) {
      throw new Error(`Missing English translation at ${path}`);
    }
    return value;
  }
  const translated = visit(source);
  if (validate) {
    for (const path of Object.keys(messages)) {
      if (!used.has(path)) throw new Error(`Unknown translation path: ${path}`);
    }
  }
  return translated;
}
