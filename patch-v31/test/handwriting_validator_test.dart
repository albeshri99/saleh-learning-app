import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/lesson/writing/handwriting_validator.dart';

void main() {
  const canvas = Size(600, 400);

  WritingSample sample(List<List<Offset>> normalized) => WritingSample(
        canvasSize: canvas,
        strokes: normalized
            .map(
              (stroke) => stroke
                  .map((p) => Offset(p.dx * canvas.width, p.dy * canvas.height))
                  .toList(),
            )
            .toList(),
      );

  List<List<Offset>> validAlif() => [
        // جسم الألف: ضربة طويلة من الأعلى إلى الأسفل مع انحناء طفولي بسيط.
        const [
          Offset(.52, .30),
          Offset(.50, .39),
          Offset(.49, .51),
          Offset(.50, .64),
          Offset(.51, .76),
          Offset(.49, .87),
        ],
        // الهمزة.
        const [
          Offset(.56, .20),
          Offset(.51, .19),
          Offset(.45, .20),
          Offset(.41, .23),
          Offset(.42, .26),
          Offset(.48, .28),
          Offset(.55, .28),
          Offset(.53, .30),
          Offset(.47, .32),
          Offset(.41, .32),
        ],
        // الفتحة.
        const [
          Offset(.42, .13),
          Offset(.46, .12),
          Offset(.51, .105),
          Offset(.56, .09),
        ],
      ];

  test('يقبل أَ الصحيحة بترتيب الجسم ثم الهمزة ثم الفتحة', () {
    final result = validateAlifFatha(sample(validAlif()));

    expect(result.isValid, isTrue, reason: result.reason);
    expect(result.score, greaterThanOrEqualTo(.64));
    expect(result.missingParts, isEmpty);
    expect(result.reason, isNull);
  });

  test('يقبل اختلافًا طفوليًا معتدلًا في الحجم والموضع والميل', () {
    final transformed = validAlif()
        .map((stroke) => stroke.map((point) {
              final centered = point - const Offset(.5, .5);
              return Offset(
                .56 + centered.dx * .88 + centered.dy * .035,
                .51 + centered.dy * .91,
              );
            }).toList())
        .toList();

    final result = validateAlifFatha(sample(transformed));

    expect(result.isValid, isTrue, reason: result.reason);
  });

  test('يتجاهل نقرة عرضية قصيرة جدًا ولا يعدها ضربة رابعة', () {
    final strokes = validAlif()
      ..insert(1, const [Offset(.20, .20), Offset(.202, .201)]);

    final result = validateAlifFatha(sample(strokes));

    expect(result.isValid, isTrue, reason: result.reason);
  });

  test('يرفض غياب الهمزة ويحددها كجزء ناقص', () {
    final strokes = validAlif();
    strokes.removeAt(1);

    final result = validateAlifFatha(sample(strokes));

    expect(result.isValid, isFalse);
    expect(result.reason, 'missingParts');
    expect(result.missingParts, contains('hamza'));
  });

  test('يرفض غياب الفتحة ويحددها كجزء ناقص', () {
    final strokes = validAlif()..removeLast();

    final result = validateAlifFatha(sample(strokes));

    expect(result.isValid, isFalse);
    expect(result.reason, 'missingParts');
    expect(result.missingParts, contains('fatha'));
  });

  test('يرفض غياب جسم الألف', () {
    final strokes = validAlif()..removeAt(0);

    final result = validateAlifFatha(sample(strokes));

    expect(result.isValid, isFalse);
    expect(result.missingParts, contains('body'));
  });

  test('يرفض ترتيب الفتحة ثم الهمزة ثم الجسم', () {
    final strokes = validAlif();
    final reversedOrder = [strokes[2], strokes[1], strokes[0]];

    final result = validateAlifFatha(sample(reversedOrder));

    expect(result.isValid, isFalse);
    expect(result.reason, 'strokeOrder');
  });

  test('يرفض تبديل موضعي الهمزة والفتحة في ترتيب اللمس', () {
    final strokes = validAlif();
    final wrongOrder = [strokes[0], strokes[2], strokes[1]];

    final result = validateAlifFatha(sample(wrongOrder));

    expect(result.isValid, isFalse);
    expect(result.reason, 'strokeOrder');
  });

  test('يرفض جسم الألف المرسوم من الأسفل إلى الأعلى', () {
    final strokes = validAlif();
    strokes[0] = strokes[0].reversed.toList();

    final result = validateAlifFatha(sample(strokes));

    expect(result.isValid, isFalse);
    expect(result.reason, 'bodyDirection');
  });

  test('يرفض وضع الفتحة أسفل الهمزة', () {
    final strokes = validAlif();
    strokes[2] =
        strokes[2].map((point) => Offset(point.dx, point.dy + .23)).toList();

    final result = validateAlifFatha(sample(strokes));

    expect(result.isValid, isFalse);
    expect(result.reason, anyOf('strokeOrder', 'partLayout'));
  });

  test('يرفض خربشة من ثلاثة خطوط', () {
    final result = validateAlifFatha(sample(const [
      [
        Offset(.20, .20),
        Offset(.80, .70),
        Offset(.24, .73),
        Offset(.78, .25),
        Offset(.28, .30),
      ],
      [
        Offset(.30, .60),
        Offset(.70, .15),
        Offset(.65, .75),
        Offset(.25, .20),
      ],
      [
        Offset(.25, .80),
        Offset(.75, .35),
        Offset(.30, .25),
        Offset(.70, .82),
      ],
    ]));

    expect(result.isValid, isFalse);
  });

  test('يرفض حرفًا صغيرًا جدًا في زاوية اللوحة', () {
    final tiny = validAlif()
        .map((stroke) => stroke
            .map((point) => Offset(.04 + point.dx * .25, .03 + point.dy * .25))
            .toList())
        .toList();

    final result = validateAlifFatha(sample(tiny));

    expect(result.isValid, isFalse);
    expect(result.reason, anyOf('bodyShape', 'sizeOrCenter'));
  });

  test('يرفض ضربة إضافية حقيقية', () {
    final strokes = validAlif()
      ..add(const [Offset(.20, .50), Offset(.35, .55)]);

    final result = validateAlifFatha(sample(strokes));

    expect(result.isValid, isFalse);
    expect(result.reason, 'unexpectedStrokeCount');
  });

  test('يرفض حجم لوحة غير صالح دون استثناء', () {
    final result = validateAlifFatha(
      WritingSample(strokes: validAlif(), canvasSize: Size.zero),
    );

    expect(result.isValid, isFalse);
    expect(result.reason, 'invalidCanvas');
    expect(result.missingParts, ['body', 'hamza', 'fatha']);
  });

  test('الفحص الطفولي يقبل اختلاف ترتيب الضربات واتجاه الفتحة', () {
    final strokes = validAlif();
    final relaxed = [
      strokes[2].reversed.toList(),
      strokes[0].reversed.toList(),
      strokes[1],
    ];

    final result = validateAlifFathaChildFriendly(sample(relaxed));

    expect(result.isValid, isTrue, reason: result.reason);
  });

  test('الفحص الطفولي يقبل ألفًا واضحًا وعلامة علوية بسيطة', () {
    final result = validateAlifFathaChildFriendly(sample(const [
      [
        Offset(.50, .28),
        Offset(.49, .44),
        Offset(.51, .62),
        Offset(.50, .84),
      ],
      [
        Offset(.42, .17),
        Offset(.50, .14),
        Offset(.59, .16),
      ],
    ]));

    expect(result.isValid, isTrue, reason: result.reason);
  });

  test('الفحص الطفولي لا يقبل خطًا أفقيًا أو خربشة كبيرة', () {
    final horizontal = validateAlifFathaChildFriendly(sample(const [
      [Offset(.20, .50), Offset(.80, .50)],
      [Offset(.35, .30), Offset(.65, .28)],
    ]));
    final scribble = validateAlifFathaChildFriendly(sample(const [
      [
        Offset(.20, .20),
        Offset(.80, .80),
        Offset(.20, .75),
        Offset(.78, .24),
        Offset(.25, .30),
      ],
      [Offset(.30, .10), Offset(.75, .38), Offset(.22, .42)],
    ]));

    expect(horizontal.isValid, isFalse);
    expect(scribble.isValid, isFalse);
  });
}
