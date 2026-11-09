// Copyright 2011, 2014 the V8 project authors. All rights reserved.
// Dart adaptation of Node v22.22.1 deps/v8/src/date/dateparser{,-inl}.{h,cc}.
// BSD-3-Clause notice: legacy_v8_timestamp.LICENSE. Provenance and limits:
// docs/reference/legacy-v8-timestamp-compatibility.md.
part of 'legacy_account_codec.dart';

/// Validation-only adaptation of the frozen source's Date.parse grammar.
/// No timestamp formatting, timezone rewriting or financial date policy.
final class _FrozenV8Timestamp {
  _FrozenV8Timestamp(String value) : scanner = _V8DateScanner(value);
  final _V8DateScanner scanner;
  final day = _V8DayComposer();
  final time = _V8TimeComposer();
  final zone = _V8ZoneComposer();

  static bool accepts(String value) {
    if (value.length > 40) return false;
    try {
      return _FrozenV8Timestamp(value)._parse();
    } catch (_) {
      return false;
    }
  }

  bool _parse() {
    var token = _parseIso();
    if (token.kind == 'invalid') return false;
    var hasNumber = day.parts.isNotEmpty;
    while (token.kind != 'end') {
      if (token.kind == 'number') {
        hasNumber = true;
        final n = token.value;
        if (scanner.skip(':')) {
          if (scanner.skip(':')) {
            if (time.parts.isNotEmpty) return false;
            time.add(n);
            time.add(0);
          } else {
            if (!time.add(n)) return false;
            if (scanner.peek.symbol('.')) scanner.next();
          }
        } else if (scanner.skip('.') && time.expecting(n)) {
          time.add(n);
          if (scanner.peek.kind != 'number') return false;
          time.addFinal(_milliseconds(scanner.next()));
        } else if (zone.expecting(n)) {
          zone.minute = n;
        } else if (time.expecting(n)) {
          time.addFinal(n);
          final peek = scanner.peek;
          if (peek.kind != 'end' &&
              peek.kind != 'space' &&
              !peek.isZ &&
              !peek.isSign) {
            return false;
          }
        } else {
          if (!day.add(n)) return false;
          scanner.skip('-');
        }
      } else if (token.isKeyword) {
        if (token.kind == 'ampm' && time.parts.isNotEmpty) {
          time.hourOffset = token.value;
        } else if (token.kind == 'month') {
          day.namedMonth = token.value;
          scanner.skip('-');
        } else if (token.kind == 'zone' && hasNumber) {
          zone.set(token.value);
        } else {
          if (hasNumber || scanner.peek.kind == 'number') return false;
        }
      } else if (token.isSign && (zone.isUtc || time.parts.isNotEmpty)) {
        zone.sign = token.value == 43 ? 1 : -1;
        var n = 0, length = 0;
        if (scanner.peek.kind == 'number') {
          final number = scanner.next();
          n = number.value;
          length = number.length;
        }
        hasNumber = true;
        if (scanner.peek.symbol(':')) {
          zone.hour = n;
          zone.minute = null;
        } else if (length == 1 || length == 2) {
          zone.hour = n;
          zone.minute = 0;
        } else if (length == 3 || length == 4) {
          zone.hour = n ~/ 100;
          zone.minute = n % 100;
        } else {
          return false;
        }
      } else if ((token.isSign || token.symbol(')')) && hasNumber) {
        return false;
      }
      token = scanner.next();
    }
    final date = day.finish(), clock = time.finish(), offset = zone.finish();
    if (date == null || clock == null || !offset.$1) return false;
    final (year, month, dateOfMonth) = date;
    // TimeClip's maximum year is275760. A signed32-second timezone offset
    // can move an instant by fewer than70calendar years. Beyond this
    // conservative bound no source-valid instant can be recovered, and host
    // microsecond construction could otherwise wrap for extreme input years.
    if (year.abs() > 275830) return false;
    final (hour, minute, second, millisecond) = clock;
    // Apply offsets inside construction so a boundary local value can become a
    // valid instant; do not construct an already clipped intermediate DateTime.
    final instant = offset.$2 == null
        ? DateTime(year, month, dateOfMonth, hour, minute, second, millisecond)
        : DateTime.utc(
            year,
            month,
            dateOfMonth,
            hour,
            minute,
            second - offset.$2!,
            millisecond,
          );
    return instant.millisecondsSinceEpoch.abs() <= 8640000000000000;
  }

  _V8DateToken _parseIso() {
    if (scanner.peek.isSign) {
      final sign = scanner.next();
      if (!scanner.peek.fixed(6)) return sign;
      final year = scanner.next().value;
      if (sign.value == 45 && year == 0) return sign;
      day.add((sign.value == 45 ? -1 : 1) * year);
    } else if (scanner.peek.fixed(4)) {
      day.add(scanner.next().value);
    } else {
      return scanner.next();
    }
    if (scanner.skip('-')) {
      if (!scanner.peek.fixed(2) || !_between(scanner.peek.value, 1, 12)) {
        return scanner.next();
      }
      day.add(scanner.next().value);
      if (scanner.skip('-')) {
        if (!scanner.peek.fixed(2) || !_between(scanner.peek.value, 1, 31)) {
          return scanner.next();
        }
        day.add(scanner.next().value);
      }
    }
    if (scanner.peek.kind != 'separator') {
      if (scanner.peek.kind != 'end') return scanner.next();
    } else {
      scanner.next();
      if (!scanner.peek.fixed(2) || !_between(scanner.peek.value, 0, 24)) {
        return _V8DateToken.invalid;
      }
      final hour24 = scanner.peek.value == 24;
      time.add(scanner.next().value);
      if (!scanner.skip(':')) return _V8DateToken.invalid;
      if (!scanner.peek.fixed(2) ||
          !_between(scanner.peek.value, 0, 59) ||
          (hour24 && scanner.peek.value > 0)) {
        return _V8DateToken.invalid;
      }
      time.add(scanner.next().value);
      if (scanner.skip(':')) {
        if (!scanner.peek.fixed(2) ||
            !_between(scanner.peek.value, 0, 59) ||
            (hour24 && scanner.peek.value > 0)) {
          return _V8DateToken.invalid;
        }
        time.add(scanner.next().value);
        if (scanner.skip('.')) {
          if (scanner.peek.kind != 'number' ||
              (hour24 && scanner.peek.value > 0)) {
            return _V8DateToken.invalid;
          }
          time.add(_milliseconds(scanner.next()));
        }
      }
      if (scanner.peek.isZ) {
        scanner.next();
        zone.set(0);
      } else if (scanner.peek.isSign) {
        zone.sign = scanner.next().value == 43 ? 1 : -1;
        if (scanner.peek.fixed(4)) {
          final hm = scanner.next().value, h = hm ~/ 100, m = hm % 100;
          if (!_between(h, 0, 23) || !_between(m, 0, 59)) {
            return _V8DateToken.invalid;
          }
          zone.hour = h;
          zone.minute = m;
        } else {
          if (!scanner.peek.fixed(2) || !_between(scanner.peek.value, 0, 23)) {
            return _V8DateToken.invalid;
          }
          zone.hour = scanner.next().value;
          if (!scanner.skip(':')) return _V8DateToken.invalid;
          if (!scanner.peek.fixed(2) || !_between(scanner.peek.value, 0, 59)) {
            return _V8DateToken.invalid;
          }
          zone.minute = scanner.next().value;
        }
      }
      if (scanner.peek.kind != 'end') return _V8DateToken.invalid;
    }
    if (zone.hour == null && time.parts.isEmpty) zone.set(0);
    day.iso = true;
    return _V8DateToken.end;
  }

  static int _milliseconds(_V8DateToken token) {
    var n = token.value, length = token.length;
    if (length == 1) return n * 100;
    if (length == 2) return n * 10;
    if (length > 3) {
      if (length > 9) length = 9;
      while (length > 3) {
        n ~/= 10;
        length--;
      }
    }
    return n;
  }

  static bool _between(int value, int low, int high) =>
      value >= low && value <= high;
}

final class _V8DateToken {
  const _V8DateToken(this.kind, [this.value = 0, this.length = 0]);
  final String kind;
  final int value, length;
  static const end = _V8DateToken('end'), invalid = _V8DateToken('invalid');
  bool symbol(String char) => kind == 'symbol' && value == char.codeUnitAt(0);
  bool fixed(int size) => kind == 'number' && length == size;
  bool get isSign => kind == 'symbol' && (value == 43 || value == 45);
  bool get isZ => kind == 'zone' && length == 1 && value == 0;
  bool get isKeyword =>
      const ['month', 'zone', 'ampm', 'separator', 'word'].contains(kind);
}

final class _V8DateScanner {
  _V8DateScanner(this.source) {
    peek = _scan();
  }
  final String source;
  int position = 0;
  late _V8DateToken peek;
  int get char => position < source.length ? source.codeUnitAt(position) : 0;
  static bool _digit(int c) => c >= 48 && c <= 57;
  static bool _space(int c) =>
      c == 9 ||
      c == 11 ||
      c == 12 ||
      c == 32 ||
      c == 160 ||
      c == 0x1680 ||
      (c >= 0x2000 && c <= 0x200a) ||
      c == 0x202f ||
      c == 0x205f ||
      c == 0x3000 ||
      c == 0xfeff;
  static bool _line(int c) => c == 10 || c == 13 || c == 0x2028 || c == 0x2029;
  _V8DateToken next() {
    final token = peek;
    peek = _scan();
    return token;
  }

  bool skip(String symbol) {
    if (!peek.symbol(symbol)) return false;
    next();
    return true;
  }

  _V8DateToken _scan() {
    if (char == 0) return _V8DateToken.end;
    if (_digit(char)) {
      final start = position;
      var n = 0, significant = 0;
      while (char == 48) {
        position++;
      }
      while (_digit(char)) {
        if (significant < 9) n = n * 10 + char - 48;
        significant++;
        position++;
      }
      return _V8DateToken('number', n, position - start);
    }
    if (const [58, 45, 43, 46, 41].contains(char)) {
      return _V8DateToken('symbol', source.codeUnitAt(position++), 1);
    }
    if (char >= 65 && !_space(char)) {
      final prefix = <int>[];
      var length = 0;
      while (char >= 65 && !_space(char)) {
        if (length < 3) prefix.add(char >= 65 && char <= 90 ? char + 32 : char);
        length++;
        position++;
      }
      final word = String.fromCharCodes(prefix);
      const months = [
        'jan',
        'feb',
        'mar',
        'apr',
        'may',
        'jun',
        'jul',
        'aug',
        'sep',
        'oct',
        'nov',
        'dec',
      ];
      if (length >= 3 && months.contains(word)) {
        return _V8DateToken('month', months.indexOf(word) + 1, length);
      }
      const keywords = {
        'am': ('ampm', 0),
        'pm': ('ampm', 12),
        'ut': ('zone', 0),
        'utc': ('zone', 0),
        'z': ('zone', 0),
        'gmt': ('zone', 0),
        'cdt': ('zone', -5),
        'cst': ('zone', -6),
        'edt': ('zone', -4),
        'est': ('zone', -5),
        'mdt': ('zone', -6),
        'mst': ('zone', -7),
        'pdt': ('zone', -7),
        'pst': ('zone', -8),
        't': ('separator', 0),
      };
      final found = length <= 3 ? keywords[word] : null;
      return found == null
          ? _V8DateToken('word', 0, length)
          : _V8DateToken(found.$1, found.$2, length);
    }
    if (_space(char) || _line(char)) {
      position++;
      return const _V8DateToken('space', 0, 1);
    }
    if (char == 40) {
      var balance = 0;
      do {
        if (char == 41) {
          balance--;
        } else if (char == 40) {
          balance++;
        }
        position++;
      } while (balance > 0 && char != 0);
      return const _V8DateToken('unknown');
    }
    position++;
    return const _V8DateToken('unknown');
  }
}

final class _V8DayComposer {
  final parts = <int>[];
  int? namedMonth;
  bool iso = false;
  bool add(int n) {
    if (parts.length == 3) return false;
    parts.add(n);
    return true;
  }

  (int, int, int)? finish() {
    if (parts.isEmpty) return null;
    while (parts.length < 3) {
      parts.add(1);
    }
    int year, month, day;
    if (namedMonth == null) {
      if (iso || parts[0] < 1 || parts[0] > 31) {
        year = parts[0];
        month = parts[1];
        day = parts[2];
      } else {
        month = parts[0];
        day = parts[1];
        year = parts[2];
      }
    } else {
      month = namedMonth!;
      if (parts[0] < 1 || parts[0] > 31) {
        year = parts[0];
        day = parts[1];
      } else {
        day = parts[0];
        year = parts[1];
      }
    }
    if (!iso) {
      if (year >= 0 && year <= 49) {
        year += 2000;
      } else if (year >= 50 && year <= 99) {
        year += 1900;
      }
    }
    if (year.abs() > 0x7fffffff ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    return (year, month, day);
  }
}

final class _V8TimeComposer {
  final parts = <int>[];
  int? hourOffset;
  bool add(int n) {
    if (parts.length == 4) return false;
    parts.add(n);
    return true;
  }

  bool expecting(int n) => (parts.length == 1 || parts.length == 2)
      ? n >= 0 && n <= 59
      : parts.length == 3 && n >= 0 && n <= 999;
  bool addFinal(int n) {
    if (!add(n)) return false;
    while (parts.length < 4) {
      parts.add(0);
    }
    return true;
  }

  (int, int, int, int)? finish() {
    while (parts.length < 4) {
      parts.add(0);
    }
    var hour = parts[0];
    final minute = parts[1], second = parts[2], ms = parts[3];
    if (hourOffset != null) {
      if (hour < 0 || hour > 12) return null;
      hour = hour % 12 + hourOffset!;
    }
    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        second < 0 ||
        second > 59 ||
        ms < 0 ||
        ms > 999) {
      if (hour != 24 || minute != 0 || second != 0 || ms != 0) return null;
    }
    return (hour, minute, second, ms);
  }
}

final class _V8ZoneComposer {
  int? sign, hour, minute;
  bool get isUtc => hour == 0 && minute == 0;
  void set(int hours) {
    sign = hours < 0 ? -1 : 1;
    hour = hours.abs();
    minute = 0;
  }

  bool expecting(int n) => hour != null && minute == null && n >= 0 && n <= 59;
  (bool, int?) finish() {
    if (sign == null) return (true, null);
    // The pinned uncompressed Node22 build uses signed32 Smi values and
    // unsigned32 intermediate offset arithmetic.
    final total = (((hour ?? 0) * 3600) + ((minute ?? 0) * 60)) & 0xffffffff;
    if (total > 0x7fffffff) return (false, null);
    return (true, sign! * total);
  }
}
