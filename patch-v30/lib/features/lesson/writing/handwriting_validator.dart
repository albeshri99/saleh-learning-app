import 'dart:math' as math;
import 'dart:ui';

/// عينة كتابة حرة كما التقطتها لوحة اللمس.
///
/// كل عنصر في [strokes] يمثل ضربة واحدة بين وضع الإصبع ورفعه. تبقى
/// الإحداثيات بوحدات اللوحة، ويحوّلها المحقق داخليًا إلى المجال 0..1 كي لا
/// تتأثر النتيجة بمقاس الجهاز.
class WritingSample {
  WritingSample({required List<List<Offset>> strokes, required this.canvasSize})
      : strokes = List.unmodifiable(
          strokes.map((stroke) => List<Offset>.unmodifiable(stroke)),
        );

  final List<List<Offset>> strokes;
  final Size canvasSize;
}

/// نتيجة فحص الكتابة الحرة.
class WritingValidationResult {
  const WritingValidationResult({
    required this.isValid,
    required this.score,
    this.missingParts = const [],
    this.reason,
  });

  final bool isValid;

  /// درجة تقريبية من صفر إلى واحد، مفيدة لضبط السماحية لاحقًا من عينات أطفال.
  final double score;

  /// أسماء الأجزاء الناقصة: body، hamza، fatha.
  final List<String> missingParts;

  /// رمز ثابت يصلح لاختيار رسالة واجهة مناسبة دون ربط المنطق بالنص المعروض.
  final String? reason;
}

/// يتحقق هندسيًا من كتابة «أَ» وفق ترتيب الفيديو المرجعي:
/// جسم الألف من الأعلى إلى الأسفل، ثم الهمزة، ثم الفتحة.
///
/// هذا ليس تعرّفًا بصريًا صارمًا؛ السماحية متعمدة لتناسب يد طفل، مع بوابات
/// تمنع قبول الخربشة أو فقد جزء من الحرف أو قلب ترتيب الضربات.
WritingValidationResult validateAlifFatha(WritingSample sample) {
  final size = sample.canvasSize;
  if (!size.width.isFinite ||
      !size.height.isFinite ||
      size.width <= 0 ||
      size.height <= 0) {
    return const WritingValidationResult(
      isValid: false,
      score: 0,
      missingParts: ['body', 'hamza', 'fatha'],
      reason: 'invalidCanvas',
    );
  }

  final normalized = sample.strokes
      .map((stroke) => _normalizeAndClean(stroke, size))
      // نتجاهل النقرات العرضية القصيرة فقط، ولا نتجاهل ضربة فعلية إضافية.
      .where((stroke) => stroke.length >= 2 && _pathLength(stroke) >= .018)
      .toList(growable: false);

  final missing = _detectMissingParts(normalized);
  if (normalized.length < 3) {
    return WritingValidationResult(
      isValid: false,
      score: (normalized.length / 3 * .45).clamp(0.0, .45),
      missingParts: missing,
      reason: 'missingParts',
    );
  }
  if (normalized.length > 3) {
    return const WritingValidationResult(
      isValid: false,
      score: .2,
      reason: 'unexpectedStrokeCount',
    );
  }

  final features = normalized.map(_StrokeFeatures.new).toList(growable: false);

  // نحدد الأدوار هندسيًا أولًا ثم نتحقق من ترتيبها الزمني. هذا يفرّق بين
  // «ترتيب خاطئ» وبين حرف مرسوم بالترتيب الصحيح لكن شكله غير مقبول.
  final bodyIndex = _mostLikelyBody(features);
  final fathaIndex = _mostLikelyFatha(features, excluding: bodyIndex);
  final hamzaIndex = ({0, 1, 2}
        ..remove(bodyIndex)
        ..remove(fathaIndex))
      .first;
  if (bodyIndex != 0 || hamzaIndex != 1 || fathaIndex != 2) {
    return const WritingValidationResult(
      isValid: false,
      score: .38,
      reason: 'strokeOrder',
    );
  }

  final body = features[0];
  final hamza = features[1];
  final fatha = features[2];

  // نختبر الحجم والمكان قبل مقاييس الاتجاه. فالحرف المصغر في زاوية اللوحة
  // ليس «جسمًا معكوسًا»، حتى لو أصبحت مسافة بدايته ونهايته صغيرة رقميًا.
  final overall = _unionBounds(features.map((e) => e.bounds));
  final sizeAndCenterScore = _sizeAndCenterScore(overall);
  if (!_hasValidSizeAndCenter(overall) || sizeAndCenterScore < .50) {
    return WritingValidationResult(
      isValid: false,
      score: (.36 * sizeAndCenterScore).clamp(0.0, .36),
      reason: 'sizeOrCenter',
    );
  }

  final bodyDirection = body.end.dy - body.start.dy;
  if (bodyDirection < math.max(.20, body.bounds.height * .62) ||
      body.monotonicDownRatio < .62) {
    return WritingValidationResult(
      isValid: false,
      score: _bodyScore(body) * .5,
      reason: 'bodyDirection',
    );
  }

  final bodyShape = _bodyScore(body);
  final hamzaShape = _hamzaScore(hamza, body);
  final fathaShape = _fathaScore(fatha, body);
  if (!_isBodyLike(body) || bodyShape < .57) {
    return WritingValidationResult(
      isValid: false,
      score: bodyShape * .55,
      reason: 'bodyShape',
    );
  }
  if (!_isHamzaLike(hamza, body) || hamzaShape < .43) {
    return WritingValidationResult(
      isValid: false,
      score: (.42 * bodyShape + .30 * hamzaShape).clamp(0.0, .72),
      reason: 'hamzaShape',
    );
  }
  if (!_isFathaLike(fatha, body) || fathaShape < .50) {
    return WritingValidationResult(
      isValid: false,
      score: (.36 * bodyShape + .24 * hamzaShape + .20 * fathaShape)
          .clamp(0.0, .80),
      reason: 'fathaShape',
    );
  }

  final layoutScore = _layoutScore(body, hamza, fatha);
  if (!_hasValidLayout(body, hamza, fatha) || layoutScore < .52) {
    return WritingValidationResult(
      isValid: false,
      score: (.28 * bodyShape +
              .22 * hamzaShape +
              .18 * fathaShape +
              .20 * layoutScore)
          .clamp(0.0, .88),
      reason: 'partLayout',
    );
  }

  final score = (.31 * bodyShape +
          .23 * hamzaShape +
          .16 * fathaShape +
          .18 * layoutScore +
          .12 * sizeAndCenterScore)
      .clamp(0.0, 1.0);
  return WritingValidationResult(
    isValid: score >= .64,
    score: score,
    reason: score >= .64 ? null : 'lowConfidence',
  );
}

List<Offset> _normalizeAndClean(List<Offset> raw, Size size) {
  final result = <Offset>[];
  for (final point in raw) {
    if (!point.dx.isFinite || !point.dy.isFinite) continue;
    final normalized = Offset(point.dx / size.width, point.dy / size.height);
    if (result.isEmpty || (normalized - result.last).distance >= .002) {
      result.add(normalized);
    }
  }
  return result;
}

class _StrokeFeatures {
  _StrokeFeatures(this.points)
      : bounds = _boundsOf(points),
        length = _pathLength(points),
        start = points.first,
        end = points.last,
        straightness = _straightness(points),
        monotonicDownRatio = _monotonicDownRatio(points),
        absoluteTurn = _absoluteTurn(points);

  final List<Offset> points;
  final Rect bounds;
  final double length;
  final Offset start;
  final Offset end;
  final double straightness;
  final double monotonicDownRatio;
  final double absoluteTurn;

  double get verticality =>
      bounds.height / math.max(.0001, bounds.width + bounds.height);
  double get horizontalAspect => bounds.width / math.max(.0001, bounds.height);
}

int _mostLikelyBody(List<_StrokeFeatures> strokes) {
  var bestIndex = 0;
  var bestScore = double.negativeInfinity;
  for (var i = 0; i < strokes.length; i++) {
    final stroke = strokes[i];
    final score = stroke.bounds.height * 2.4 +
        stroke.verticality * .65 +
        stroke.straightness * .18 -
        stroke.bounds.width * .35;
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  return bestIndex;
}

int _mostLikelyFatha(List<_StrokeFeatures> strokes, {required int excluding}) {
  var bestIndex = excluding == 0 ? 1 : 0;
  var bestScore = double.negativeInfinity;
  for (var i = 0; i < strokes.length; i++) {
    if (i == excluding) continue;
    final stroke = strokes[i];
    final score = math.min(stroke.horizontalAspect, 5) * .34 +
        stroke.straightness * .42 -
        stroke.bounds.center.dy * .28 -
        math.min(stroke.absoluteTurn, 8) * .035;
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  return bestIndex;
}

bool _isBodyLike(_StrokeFeatures body) =>
    body.bounds.height >= .30 &&
    body.verticality >= .66 &&
    body.straightness >= .55 &&
    body.absoluteTurn <= 4.8;

bool _isHamzaLike(_StrokeFeatures hamza, _StrokeFeatures body) {
  final heightRatio = hamza.bounds.height / math.max(.001, body.bounds.height);
  final widthRatio = hamza.bounds.width / math.max(.001, body.bounds.height);
  return hamza.bounds.width >= .035 &&
      hamza.bounds.height >= .025 &&
      heightRatio >= .055 &&
      heightRatio <= .48 &&
      widthRatio >= .07 &&
      widthRatio <= .68 &&
      hamza.absoluteTurn >= .55 &&
      hamza.absoluteTurn <= 13 &&
      hamza.straightness <= .92;
}

bool _isFathaLike(_StrokeFeatures fatha, _StrokeFeatures body) {
  final lengthRatio = fatha.length / math.max(.001, body.bounds.height);
  return fatha.bounds.width >= .045 &&
      fatha.horizontalAspect >= 1.20 &&
      fatha.straightness >= .64 &&
      fatha.absoluteTurn <= 3.2 &&
      lengthRatio >= .075 &&
      lengthRatio <= .55;
}

double _bodyScore(_StrokeFeatures body) {
  final direction = _ramp(
    body.end.dy - body.start.dy,
    low: .16,
    high: math.max(.30, body.bounds.height * .82),
  );
  final height = _ramp(body.bounds.height, low: .25, high: .48);
  final verticality = _ramp(body.verticality, low: .55, high: .82);
  final monotonic = _ramp(body.monotonicDownRatio, low: .50, high: .84);
  final straight = _rangeScore(
    body.straightness,
    min: .48,
    idealMin: .68,
    idealMax: .98,
    max: 1.01,
  );
  final canonical = _canonicalSimilarity(body.points, _canonicalBody);
  return (.20 * direction +
          .18 * height +
          .19 * verticality +
          .18 * monotonic +
          .12 * straight +
          .13 * canonical)
      .clamp(0.0, 1.0);
}

double _hamzaScore(_StrokeFeatures hamza, _StrokeFeatures body) {
  final heightRatio = hamza.bounds.height / math.max(.001, body.bounds.height);
  final widthRatio = hamza.bounds.width / math.max(.001, body.bounds.height);
  final height = _rangeScore(
    heightRatio,
    min: .04,
    idealMin: .11,
    idealMax: .31,
    max: .52,
  );
  final width = _rangeScore(
    widthRatio,
    min: .05,
    idealMin: .16,
    idealMax: .42,
    max: .72,
  );
  final curve = _rangeScore(
    hamza.absoluteTurn,
    min: .35,
    idealMin: 1.25,
    idealMax: 6.8,
    max: 13.5,
  );
  final canonical = _canonicalSimilarity(hamza.points, _canonicalHamza);
  return (.22 * height + .22 * width + .25 * curve + .31 * canonical)
      .clamp(0.0, 1.0);
}

double _fathaScore(_StrokeFeatures fatha, _StrokeFeatures body) {
  final lengthRatio = fatha.length / math.max(.001, body.bounds.height);
  final length = _rangeScore(
    lengthRatio,
    min: .05,
    idealMin: .12,
    idealMax: .32,
    max: .58,
  );
  final aspect = _ramp(fatha.horizontalAspect, low: 1, high: 3.2);
  final straight = _ramp(fatha.straightness, low: .55, high: .91);
  final canonical = math.max(
    _canonicalSimilarity(fatha.points, _canonicalFatha),
    _canonicalSimilarity(fatha.points.reversed.toList(), _canonicalFatha),
  );
  return (.23 * length + .23 * aspect + .24 * straight + .30 * canonical)
      .clamp(0.0, 1.0);
}

bool _hasValidLayout(
  _StrokeFeatures body,
  _StrokeFeatures hamza,
  _StrokeFeatures fatha,
) {
  final bodyTopX = body.start.dx;
  return hamza.bounds.center.dy < body.bounds.top + .07 &&
      fatha.bounds.center.dy < hamza.bounds.center.dy - .012 &&
      body.bounds.top - hamza.bounds.center.dy <= .24 &&
      hamza.bounds.center.dy - fatha.bounds.center.dy <= .20 &&
      (hamza.bounds.center.dx - bodyTopX).abs() <= .20 &&
      (fatha.bounds.center.dx - bodyTopX).abs() <= .22;
}

double _layoutScore(
  _StrokeFeatures body,
  _StrokeFeatures hamza,
  _StrokeFeatures fatha,
) {
  final bodyTopX = body.start.dx;
  final hamzaAbove = _ramp(
    body.bounds.top + .08 - hamza.bounds.center.dy,
    low: 0,
    high: .08,
  );
  final fathaAbove = _ramp(
    hamza.bounds.center.dy - fatha.bounds.center.dy,
    low: 0,
    high: .08,
  );
  final hamzaAligned =
      1 - ((hamza.bounds.center.dx - bodyTopX).abs() / .22).clamp(0.0, 1.0);
  final fathaAligned =
      1 - ((fatha.bounds.center.dx - bodyTopX).abs() / .24).clamp(0.0, 1.0);
  return (.30 * hamzaAbove +
          .30 * fathaAbove +
          .22 * hamzaAligned +
          .18 * fathaAligned)
      .clamp(0.0, 1.0);
}

bool _hasValidSizeAndCenter(Rect bounds) =>
    bounds.height >= .40 &&
    bounds.height <= .94 &&
    bounds.width >= .065 &&
    bounds.width <= .62 &&
    bounds.center.dx >= .20 &&
    bounds.center.dx <= .80 &&
    bounds.center.dy >= .24 &&
    bounds.center.dy <= .76;

double _sizeAndCenterScore(Rect bounds) {
  final height = _rangeScore(
    bounds.height,
    min: .34,
    idealMin: .55,
    idealMax: .82,
    max: .98,
  );
  final width = _rangeScore(
    bounds.width,
    min: .045,
    idealMin: .12,
    idealMax: .36,
    max: .68,
  );
  final centerX = 1 - ((bounds.center.dx - .5).abs() / .31).clamp(0.0, 1.0);
  final centerY = 1 - ((bounds.center.dy - .5).abs() / .28).clamp(0.0, 1.0);
  return (.34 * height + .20 * width + .24 * centerX + .22 * centerY)
      .clamp(0.0, 1.0);
}

List<String> _detectMissingParts(List<List<Offset>> strokes) {
  const names = ['body', 'hamza', 'fatha'];
  if (strokes.isEmpty) return names;

  final features = strokes.map(_StrokeFeatures.new).toList(growable: false);
  final present = <String>{};
  final bodyIndex = _mostLikelyBody(features);
  final body = features[bodyIndex];
  if (_isBodyLike(body)) present.add('body');

  for (var i = 0; i < features.length; i++) {
    if (i == bodyIndex) continue;
    final stroke = features[i];
    if (_isFathaLike(stroke, body)) {
      present.add('fatha');
    } else if (_isHamzaLike(stroke, body)) {
      present.add('hamza');
    }
  }
  return names.where((part) => !present.contains(part)).toList(growable: false);
}

double _canonicalSimilarity(List<Offset> points, List<Offset> canonical) {
  final a = _normalizeLocal(_resample(points, 32));
  final b = _normalizeLocal(_resample(canonical, 32));
  if (a.length != b.length || a.isEmpty) return 0;
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).distance;
  }
  final mean = sum / a.length;
  return (1 - mean / .48).clamp(0.0, 1.0);
}

List<Offset> _normalizeLocal(List<Offset> points) {
  if (points.isEmpty) return const [];
  final bounds = _boundsOf(points);
  final scale = math.max(.0001, math.max(bounds.width, bounds.height));
  return points
      .map((p) => Offset(
            (p.dx - bounds.center.dx) / scale,
            (p.dy - bounds.center.dy) / scale,
          ))
      .toList(growable: false);
}

List<Offset> _resample(List<Offset> points, int count) {
  if (points.isEmpty) return const [];
  if (points.length == 1) return List.filled(count, points.first);
  final cumulative = <double>[0];
  for (var i = 1; i < points.length; i++) {
    cumulative.add(cumulative.last + (points[i] - points[i - 1]).distance);
  }
  final total = cumulative.last;
  if (total <= .000001) return List.filled(count, points.first);

  final result = <Offset>[];
  var segment = 1;
  for (var i = 0; i < count; i++) {
    final target = total * i / (count - 1);
    while (segment < cumulative.length - 1 && cumulative[segment] < target) {
      segment++;
    }
    final startDistance = cumulative[segment - 1];
    final endDistance = cumulative[segment];
    final t = endDistance == startDistance
        ? 0.0
        : (target - startDistance) / (endDistance - startDistance);
    result.add(Offset.lerp(points[segment - 1], points[segment], t)!);
  }
  return result;
}

double _pathLength(List<Offset> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += (points[i] - points[i - 1]).distance;
  }
  return total;
}

double _straightness(List<Offset> points) {
  final length = _pathLength(points);
  if (length <= .000001) return 0;
  return ((points.last - points.first).distance / length).clamp(0.0, 1.0);
}

double _monotonicDownRatio(List<Offset> points) {
  var down = 0.0;
  var verticalTravel = 0.0;
  for (var i = 1; i < points.length; i++) {
    final dy = points[i].dy - points[i - 1].dy;
    verticalTravel += dy.abs();
    if (dy > 0) down += dy;
  }
  if (verticalTravel <= .000001) return 0;
  return (down / verticalTravel).clamp(0.0, 1.0);
}

double _absoluteTurn(List<Offset> points) {
  final sampled = _resample(points, math.min(20, math.max(3, points.length)));
  var turn = 0.0;
  for (var i = 2; i < sampled.length; i++) {
    final a = sampled[i - 1] - sampled[i - 2];
    final b = sampled[i] - sampled[i - 1];
    if (a.distance <= .000001 || b.distance <= .000001) continue;
    final cross = a.dx * b.dy - a.dy * b.dx;
    final dot = a.dx * b.dx + a.dy * b.dy;
    turn += math.atan2(cross, dot).abs();
  }
  return turn;
}

Rect _boundsOf(Iterable<Offset> points) {
  final iterator = points.iterator;
  if (!iterator.moveNext()) return Rect.zero;
  var left = iterator.current.dx;
  var right = left;
  var top = iterator.current.dy;
  var bottom = top;
  while (iterator.moveNext()) {
    final point = iterator.current;
    left = math.min(left, point.dx);
    right = math.max(right, point.dx);
    top = math.min(top, point.dy);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

Rect _unionBounds(Iterable<Rect> bounds) {
  final iterator = bounds.iterator;
  if (!iterator.moveNext()) return Rect.zero;
  var result = iterator.current;
  while (iterator.moveNext()) {
    result = result.expandToInclude(iterator.current);
  }
  return result;
}

double _ramp(double value, {required double low, required double high}) {
  if (high <= low) return value >= high ? 1 : 0;
  return ((value - low) / (high - low)).clamp(0.0, 1.0);
}

double _rangeScore(
  double value, {
  required double min,
  required double idealMin,
  required double idealMax,
  required double max,
}) {
  if (value <= min || value >= max) return 0;
  if (value >= idealMin && value <= idealMax) return 1;
  if (value < idealMin) return (value - min) / (idealMin - min);
  return (max - value) / (max - idealMax);
}

const _canonicalBody = [
  Offset(.54, 0),
  Offset(.49, .15),
  Offset(.48, .36),
  Offset(.50, .59),
  Offset(.52, .80),
  Offset(.49, 1),
];

const _canonicalHamza = [
  Offset(.72, .05),
  Offset(.52, 0),
  Offset(.30, .10),
  Offset(.16, .31),
  Offset(.20, .54),
  Offset(.43, .70),
  Offset(.72, .72),
  Offset(.62, .86),
  Offset(.31, 1),
  Offset(.08, .96),
];

const _canonicalFatha = [
  Offset(0, .78),
  Offset(.30, .57),
  Offset(.63, .32),
  Offset(1, 0),
];
