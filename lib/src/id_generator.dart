/// Process-wide id generation.
///
/// An id built from a clock reading alone repeats when two records are made
/// in the same tick, and a store replaces a record that has the same id
/// without raising an error. The counter makes every id issued by this process
/// distinct whatever the clock does.
library;

int _sequence = 0;

/// A new id of the form `<prefix><separator><microseconds><separator><sequence>`.
String generateId(String prefix, {String separator = '_'}) {
  _sequence += 1;
  return '$prefix$separator${DateTime.now().microsecondsSinceEpoch}'
      '$separator$_sequence';
}
