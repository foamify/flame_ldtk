/// {@template _simple_flips}
/// LDtk represents all flips and rotation using three possible flips:
/// horizontal, vertical and diagonal.
/// This class converts that representation to a simpler one, that uses one
/// angle (with pi/2 steps) and one flip (horizontal). All vertical flips are
/// represented as horizontal flips + 180º.
/// Further reference:
/// https://doc.mapeditor.org/en/stable/reference/tmx-map-format/#tile-flipping.
///
/// `cos` and `sin` are the cosine and sine of the rotation respectively, and
/// and are provided for simple calculation with RSTransform.
/// Further reference:
/// https://api.flutter.dev/flutter/dart-ui/RSTransform/RSTransform.html
/// {@endtemplate}
class SimpleFlips {
  /// The angle (in steps of pi/2 rads), clockwise, around the center of the tile.
  final int angle;

  /// The cosine of the rotation.
  final int cos;

  /// The sine of the rotation.
  final int sin;

  /// Whether to flip (across a central vertical axis).
  final bool flip;

  /// {@macro _simple_flips}
  SimpleFlips(this.angle, this.cos, this.sin, this.flip);

  /// This is the conversion from the truth table that I drew.
  factory SimpleFlips.fromFlipBits(int f) {
    int angle, cos, sin;
    bool flip;

    switch (f) {

      /// No flip
      case 0:
        angle = 0;
        cos = 1;
        sin = 0;
        flip = false;
        break;

      /// X flip
      case 1:
        angle = 0;
        cos = 1;
        sin = 0;
        flip = true;
        break;

      /// Y flip
      case 2:
        angle = 2;
        cos = -1;
        sin = 0;
        flip = false;
        break;

      /// X & Y flip
      case 3:
        angle = 2;
        cos = -1;
        sin = 0;
        flip = true;
        break;
      default:
        // this should be exhaustive
        throw 'Invalid combination of booleans: $f';
    }

    return SimpleFlips(angle, cos, sin, flip);
  }
}
