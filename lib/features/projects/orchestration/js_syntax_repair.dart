/// Deterministic repairs for the small class of JavaScript/TypeScript *syntax*
/// errors that LLM agents produce and then cannot fix by re-writing.
///
/// Why this exists: a generated marketing line like
/// `description: 'Changes don't break.'` is a single-quoted string containing a
/// bare apostrophe. The build fails (`Expected ',', got 't'`). The CI fixer,
/// handed that failpoint, re-writes the whole file and the model emits the same
/// `don't` again — so the error survives every round and the convergence loop
/// gives up ("leaving for manual review"). Escaping the apostrophe (`don\'t`)
/// is a mechanical, unambiguous fix that the deterministic pass applies before
/// any LLM turn, so this class of failure is nailed without model luck.
library;

/// Returns [content] with every unescaped apostrophe that sits INSIDE a
/// single-quoted string literal escaped (`don't` -> `don\'t`), or null when
/// there is nothing to repair.
///
/// Only single-quoted STRING LITERALS are touched. Apostrophes inside
/// double-quoted strings, template literals (backticks), comments, and code are
/// left exactly as-is. A `'` is treated as a string terminator (not an
/// apostrophe) unless the very next character is a letter: in valid JS a closing
/// string quote is always followed by a non-letter (`,` `}` `)` `;` `.` a
/// space ...), whereas a contraction (`don't`, `isn't`, ...) is always
/// letter-apostrophe-letter. That single disambiguation is what keeps the repair
/// safe, and it is idempotent (already-escaped `don\'t` is left untouched).
String? repairJsStringQuoting(String content) {
  final out = StringBuffer();
  final n = content.length;
  const code = 0, single = 1, double = 2, template = 3, lineCmt = 4, blockCmt = 5;
  var state = code;
  var changed = false;
  var i = 0;
  while (i < n) {
    final ch = content[i];
    final next = i + 1 < n ? content[i + 1] : '';
    if (state == lineCmt) {
      out.write(ch);
      if (ch == '\n') state = code;
    } else if (state == blockCmt) {
      out.write(ch);
      if (ch == '*' && next == '/') {
        out.write(next);
        i++;
        state = code;
      }
    } else if (state == template) {
      if (ch == '\\') {
        out.write(ch);
        if (next.isNotEmpty) {
          out.write(next);
          i++;
        }
      } else {
        out.write(ch);
        if (ch == '`') state = code;
      }
    } else if (state == double) {
      if (ch == '\\') {
        out.write(ch);
        if (next.isNotEmpty) {
          out.write(next);
          i++;
        }
      } else {
        out.write(ch);
        // A double-quoted string can't span a newline; a bare `\n` ends it
        // (an unterminated string is a different bug we deliberately don't
        // chase — we only want to fix the apostrophe class).
        if (ch == '"' || ch == '\n') state = code;
      }
    } else if (state == single) {
      if (ch == '\\') {
        // Already escaped — copy the escape pair verbatim (idempotency).
        out.write(ch);
        if (next.isNotEmpty) {
          out.write(next);
          i++;
        }
      } else if (ch == '\'') {
        // A terminator — OR an apostrophe (contraction) if a letter follows.
        if (_isLetter(next)) {
          out.write('\\');
          out.write('\'');
          changed = true;
        } else {
          out.write(ch);
          state = code;
        }
      } else {
        out.write(ch);
        if (ch == '\n') state = code; // unterminated; reset defensively
      }
    } else {
      // code
      if (ch == '/' && next == '/') {
        state = lineCmt;
        out.write(ch);
      } else if (ch == '/' && next == '*') {
        state = blockCmt;
        out.write(ch);
      } else if (ch == '\'') {
        state = single;
        out.write(ch);
      } else if (ch == '"') {
        state = double;
        out.write(ch);
      } else if (ch == '`') {
        state = template;
        out.write(ch);
      } else {
        out.write(ch);
      }
    }
    i++;
  }
  return changed ? out.toString() : null;
}

bool _isLetter(String c) {
  if (c.isEmpty) return false;
  final u = c.codeUnitAt(0);
  return (u >= 0x61 && u <= 0x7a) || (u >= 0x41 && u <= 0x5a);
}
