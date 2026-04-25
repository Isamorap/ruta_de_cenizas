import 'dart:ui';

class PerspectiveUtils {
  static const double vanishingPointY = -500;
  static const double baseRowHeight = 50;
  static const double baseTileWidth = 100;
  static const double depthFactor = 0.5;

  /// Projects a 3D grid coordinate to 2D screen space.
  /// [row] is the distance from the camera (0 is closest).
  /// [col] is the horizontal position (center is 0).
  /// [screenSize] is the viewport size.
  static Offset project(double row, double col, Size screenSize, {double cameraRowOffset = 0}) {
    double z = (row.toDouble() - cameraRowOffset) + 3.0; 
    if (z < 0.1) z = 0.1; 
    double scale = 3.0 / z; 

    double centerX = screenSize.width / 2;
    double centerY = screenSize.height * 0.8; // Base of the mountain

    // Y position goes "up" (negative screen Y) as row increases
    // We use an exponential/progresive height
    double y = centerY - (baseRowHeight * (1 - scale) * 5); 
    
    // X position relative to center
    double x = centerX + (col * baseTileWidth * scale);

    return Offset(x, y);
  }

  static double getScale(double row, {double cameraRowOffset = 0}) {
    double z = (row.toDouble() - cameraRowOffset) + 3.0;
    if (z < 0.1) z = 0.1;
    return 3.0 / z;
  }
}
