/// Guard expression evaluation for the behavior engine.
///
/// A guard is an author-written expression evaluated against the run
/// `state` (a `Map<String, dynamic>`). Unlike a plain boolean condition it
/// returns the *resolved value* — a bare state reference yields whatever it
/// holds (`100`, `'paused'`, `true`, …), while comparison / boolean
/// expressions yield a `bool`. The engine routes that value to an outcome
/// via the step's `then` map, so the core never enumerates a fixed set of
/// condition kinds.
library;

/// Evaluates guard expressions over a state map.
class GuardEvaluator {
  const GuardEvaluator();

  /// Evaluate [expr] against [state]. Returns the resolved value (any type).
  /// An empty expression is `true` (no guard = always proceed).
  dynamic evaluate(String expr, Map<String, dynamic> state) {
    final trimmed = expr.trim();
    if (trimmed.isEmpty) return true;
    return _eval(trimmed, state);
  }

  /// Convenience: the truthiness of a guard result, used for default routing.
  /// `bool` → itself · `num` → non-zero · `String` → non-empty · `null` →
  /// false · anything else → true.
  static bool truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value == null) return false;
    return true;
  }

  dynamic _eval(String expr, Map<String, dynamic> state) {
    var s = expr.trim();
    if (s.isEmpty) return true;

    // Peel a single matched outer paren pair wrapping the whole expression.
    while (s.length >= 2 &&
        s.startsWith('(') &&
        s.endsWith(')') &&
        _parensWrapWhole(s)) {
      s = s.substring(1, s.length - 1).trim();
      if (s.isEmpty) return true;
    }

    // Boolean combinators (lowest precedence first). Sub-expressions recurse.
    final orParts = _splitTop(s, '||');
    if (orParts.length > 1) {
      return orParts.any((p) => truthy(_eval(p, state)));
    }
    final andParts = _splitTop(s, '&&');
    if (andParts.length > 1) {
      return andParts.every((p) => truthy(_eval(p, state)));
    }

    // Comparators — longer operators first so `>=` beats `>`.
    for (final op in const <String>['!=', '>=', '<=', '==', '>', '<']) {
      final idx = _indexOfTop(s, op);
      if (idx < 0) continue;
      final lhs = _resolve(s.substring(0, idx).trim(), state);
      final rhs = _resolve(s.substring(idx + op.length).trim(), state);
      return _compare(op, lhs, rhs);
    }

    // Leaf — a literal or a state reference, returned as its raw value.
    return _resolve(s, state);
  }

  dynamic _compare(String op, dynamic lhs, dynamic rhs) {
    switch (op) {
      case '==':
        return _eq(lhs, rhs);
      case '!=':
        return !_eq(lhs, rhs);
      default:
        final l = _asNum(lhs);
        final r = _asNum(rhs);
        if (l == null || r == null) return false;
        switch (op) {
          case '>':
            return l > r;
          case '<':
            return l < r;
          case '>=':
            return l >= r;
          case '<=':
            return l <= r;
        }
    }
    return false;
  }

  bool _eq(dynamic a, dynamic b) {
    final an = _asNum(a);
    final bn = _asNum(b);
    if (an != null && bn != null) return an == bn;
    return '$a' == '$b';
  }

  num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  /// Resolve a token to a value: literal (`true`/`false`/number/quoted
  /// string) or a dot-path lookup into [state]. Unknown paths → `null`.
  dynamic _resolve(String token, Map<String, dynamic> state) {
    final t = token.trim();
    if (t.isEmpty) return null;
    if (t == 'true') return true;
    if (t == 'false') return false;
    if (t == 'null') return null;
    if ((t.startsWith("'") && t.endsWith("'")) ||
        (t.startsWith('"') && t.endsWith('"'))) {
      return t.substring(1, t.length - 1);
    }
    final n = num.tryParse(t);
    if (n != null) return n;

    dynamic cursor = state;
    for (final part in t.split('.')) {
      if (cursor is Map && cursor.containsKey(part)) {
        cursor = cursor[part];
      } else {
        return null;
      }
    }
    return cursor;
  }

  bool _parensWrapWhole(String s) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0 && i != s.length - 1) return false;
      }
    }
    return depth == 0;
  }

  List<String> _splitTop(String s, String sep) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i <= s.length - sep.length; i++) {
      final c = s[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (depth == 0 && s.substring(i, i + sep.length) == sep) {
        parts.add(s.substring(start, i));
        start = i + sep.length;
        i += sep.length - 1;
      }
    }
    parts.add(s.substring(start));
    return parts.length == 1 ? parts : parts.map((p) => p.trim()).toList();
  }

  int _indexOfTop(String s, String op) {
    var depth = 0;
    for (var i = 0; i <= s.length - op.length; i++) {
      final c = s[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (depth == 0 && s.substring(i, i + op.length) == op) {
        // Avoid matching '>' inside '>=' / '<=' / '!=' / '=='.
        if (op.length == 1) {
          final next = i + 1 < s.length ? s[i + 1] : '';
          if (next == '=') continue;
          if (op == '>' || op == '<') {
            // ok
          }
        }
        return i;
      }
    }
    return -1;
  }
}
