String literal(Object? o) {
  if (o == null || o is num || o is bool) return '<$o>';
  // TODO Truncate long strings?
  // TODO: handle strings with embedded `'`
  // TODO: special handling of multi-line strings?
  if (o is String) return "'$o'";
  // TODO Truncate long collections?
  return '$o';
}

Iterable<String> indent(Iterable<String> lines) => lines.map((l) => '  $l');
