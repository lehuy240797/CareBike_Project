/// AI provider configuration for the photo inspection scanner (tires & brake pads).

const String visionApiBaseUrl = String.fromEnvironment(
  'VISION_API_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

/// The YOLO model detects defects, not the part type, so we label the scanned
/// component with a fixed value. Change to 'bike' or 'brake_pad' if your model
/// is trained for a different part.
const String visionComponent = 'tire';
