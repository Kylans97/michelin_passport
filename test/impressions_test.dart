import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/analytics/analytics_properties.dart';
import 'package:michelin_passport/core/analytics/impressions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final buffer = ImpressionBuffer.instance;

  setUp(buffer.reset);
  tearDown(buffer.reset);

  test('the same card on the same surface counts once', () {
    for (var i = 0; i < 20; i++) {
      trackImpression(
        AnalyticsEntityType.restaurant,
        'r1',
        ImpressionSurface.guides,
      );
    }
    expect(buffer.pendingCount, 1);
  });

  test('a different surface, id or type is a separate impression', () {
    trackImpression(
      AnalyticsEntityType.restaurant,
      'r1',
      ImpressionSurface.guides,
    );
    trackImpression(
      AnalyticsEntityType.restaurant,
      'r1',
      ImpressionSurface.rankings,
    );
    trackImpression(
      AnalyticsEntityType.restaurant,
      'r2',
      ImpressionSurface.guides,
    );
    trackImpression(AnalyticsEntityType.hotel, 'r1', ImpressionSurface.guides);
    trackImpression(
      AnalyticsEntityType.privateChef,
      'c1',
      ImpressionSurface.privateChefs,
    );
    trackImpression(AnalyticsEntityType.event, 'e1', ImpressionSurface.events);
    expect(buffer.pendingCount, 6);
  });

  test('entity types without impressions are ignored', () {
    trackImpression(
      AnalyticsEntityType.newsArticle,
      'n1',
      ImpressionSurface.explore,
    );
    expect(buffer.pendingCount, 0);
  });

  test('reset clears the dedupe window as well as the pending batch', () {
    trackImpression(AnalyticsEntityType.event, 'e1', ImpressionSurface.events);
    buffer.reset();
    expect(buffer.pendingCount, 0);
    trackImpression(AnalyticsEntityType.event, 'e1', ImpressionSurface.events);
    expect(buffer.pendingCount, 1);
  });

  test('flush without Supabase initialised swallows the error and keeps '
      'the dedupe window', () async {
    trackImpression(AnalyticsEntityType.hotel, 'h1', ImpressionSurface.map);
    await expectLater(buffer.flush(), completes);
    expect(buffer.pendingCount, 0);
    // Still inside the 30-minute window: not re-counted after the send.
    trackImpression(AnalyticsEntityType.hotel, 'h1', ImpressionSurface.map);
    expect(buffer.pendingCount, 0);
  });
}
