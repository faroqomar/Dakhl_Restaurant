import 'dart:math';

import 'package:madar_domain/madar_domain.dart';

/// Formatting and parsing helpers for catalog and inventory presentation.
abstract final class CatalogFormatters {
  static final BigInt maxMovementLimit = BigInt.from(1000000000000);

  static String formatPrice(int price) {
    final sign = price < 0 ? '-' : '';
    final absStr = price.abs().toString();
    final buffer = StringBuffer();
    final len = absStr.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(absStr[i]);
    }
    return '$sign$buffer';
  }

  static String formatQuantity(BigInt units) {
    final decimal = ExactDecimal.fromUnits(units, 3);
    final str = decimal.toString();
    if (str.endsWith('.000')) {
      return str.substring(0, str.length - 4);
    }
    if (str.endsWith('00')) {
      return str.substring(0, str.length - 2);
    }
    if (str.endsWith('0')) {
      return str.substring(0, str.length - 1);
    }
    return str;
  }

  static BigInt parseQuantity(
    String input, {
    bool signed = false,
    bool positive = false,
  }) => ExactDecimal.parse(
    input.trim(),
    scale: 3,
    maxAbsUnits: maxMovementLimit,
    signed: signed,
    positive: positive,
    normalizeDigits: true,
    allowGrouping: true,
    allowArabicDecimal: true,
    allowExponent: true,
  ).units;

  static DateOnly parseDate(String input) =>
      DateOnly.parse(input.trim(), minimumYear: 1000, maximumYear: 9999);

  static DateOnly today() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return DateOnly.parse('$y-$m-$d', minimumYear: 1000, maximumYear: 9999);
  }

  static String generateId(String prefix) {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String currentIsoTimestamp() =>
      DateTime.now().toUtc().toIso8601String();

  static String errorMessage(String? code) => switch (code) {
    'missing_product' => 'لم يتم العثور على الصنف.',
    'duplicate_product' => 'رمز الصنف أو اسمه مسجل مسبقاً.',
    'stale_revision' => 'تغيّرت البيانات المحفوظة؛ أعد القراءة قبل المتابعة.',
    'busy' => 'عملية سابقة قيد التنفيذ؛ انتظر قليلاً.',
    'disposed' => 'تم إغلاق النموذج.',
    'invalid_opening_stock' => 'الكمية الافتتاحية غير صالحة للصنف الجديد.',
    'missing_stock_entry' => 'لم يتم العثور على حركة المخزون المطلوبة.',
    'invalid_stock_reversal' =>
      'تعذّر عكس الحركة؛ إما أنها عكست سابقاً أو تؤدي إلى رصيد مخزني سالب.',
    'invalid_stock_quantity' ||
    'invalid_decimal' ||
    'out_of_range' ||
    'invalid_precision' ||
    'invalid_sign' => 'الكمية المدخلة غير صالحة.',
    'insufficient_stock' => 'الرصيد المخزني لا يكفي لتسجيل هذه الحركة.',
    'commit_unknown' => 'تعذّر تأكيد الحفظ؛ أعد التحقق من الحسابات.',
    'invalid_photo' => 'صورة الصنف المحددة غير مدعومة.',
    'required_name' => 'اسم الصنف مطلوب.',
    'required_reason' => 'سبب الحركة أو التصحيح مطلوب.',
    'zero_quantity' => 'يجب إدخال كمية غير صفرية.',
    _ => 'تعذّر حفظ التغيير؛ بقيت مدخلاتك، أعد المحاولة.',
  };
}
