import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_hunter/services/shield_breaker_service.dart';
import 'package:dio/dio.dart';

void main() {
  group('ShieldBreakerService (The Inspector)', () {
    late ShieldBreakerService shieldBreaker;

    setUp(() {
      shieldBreaker = ShieldBreakerService();
      // Reset internal state if possible, or create a new instance
      shieldBreaker.resetH5Status();
    });

    test('Should rotate User-Agents dynamically', () {
      final ua1 = shieldBreaker.getRandomUserAgent();
      // Sleep slightly to ensure time-based randomness changes
      // In a real test we might mock DateTime, but here we just check format
      expect(ua1, contains('Mozilla/5.0'));
      
      // Call multiple times to see if we get different ones eventually (probabilistic)
      final Set<String> uas = {};
      for (int i = 0; i < 20; i++) {
        uas.add(shieldBreaker.getRandomUserAgent());
      }
      // Assuming pool size > 1, we should likely see more than 1 UA
      expect(uas.length, greaterThan(1));
    });

    test('Should trigger Circuit Breaker after failures', () {
      // 1. Initial state
      expect(shieldBreaker.getFallbackProtocol(), equals('APP_API')); // Default

      // 2. Simulate API failures -> Switch to H5
      shieldBreaker.executeBreakerStrategy(ShieldLevel.softBan, 'test');
      shieldBreaker.executeBreakerStrategy(ShieldLevel.softBan, 'test');
      shieldBreaker.executeBreakerStrategy(ShieldLevel.softBan, 'test');
      
      expect(shieldBreaker.getFallbackProtocol(), equals('H5_API'));

      // 3. Simulate H5 failures -> Trigger Circuit Breaker
      shieldBreaker.recordH5Failure();
      shieldBreaker.recordH5Failure();
      shieldBreaker.recordH5Failure(); // 3rd failure

      // analyzeResponse checks circuit breaker state
      final level = shieldBreaker.analyzeResponse(null, null);
      expect(level, equals(ShieldLevel.hardBan)); // Should escalate to Hard Ban or Stop
    });
  });
}
