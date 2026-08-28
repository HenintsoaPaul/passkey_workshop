/// Date helpers.
///
/// Written by hand rather than pulled from `intl` to keep the dependency list
/// as it is; the app only needs three fixed French formats.
const _monthsShort = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// `24 oct. 2023`
String formatShortDate(DateTime date) {
  return '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';
}

/// `24 OCT. 2023 • 14:32:05 UTC`, the audit trail format.
String formatAuditTimestamp(DateTime timestamp) {
  final utc = timestamp.toUtc();

  return '${_two(utc.day)} ${_monthsShort[utc.month - 1].toUpperCase()} '
      '${utc.year} • '
      '${_two(utc.hour)}:${_two(utc.minute)}:${_two(utc.second)} UTC';
}

/// `il y a 2 h`, falling back to a plain date beyond a week.
///
/// [now] is injectable so tests do not depend on the wall clock.
String formatRelative(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final elapsed = reference.difference(date);

  if (elapsed.inMinutes < 1) {
    return "à l'instant";
  }

  if (elapsed.inHours < 1) {
    return 'il y a ${elapsed.inMinutes} min';
  }

  if (elapsed.inDays < 1) {
    return 'il y a ${elapsed.inHours} h';
  }

  if (elapsed.inDays == 1) {
    return 'hier';
  }

  if (elapsed.inDays < 7) {
    return 'il y a ${elapsed.inDays} jours';
  }

  return formatShortDate(date);
}
