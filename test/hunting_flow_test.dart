import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_hunter_pro/models/account.dart';
import 'package:ticket_hunter_pro/models/hunting_result.dart';
import 'package:ticket_hunter_pro/models/show.dart';
import 'package:ticket_hunter_pro/models/platform_config.dart';
import 'package:ticket_hunter_pro/providers/ticket_hunter_provider.dart';
import 'package:ticket_hunter_pro/services/unified_ticket_service.dart';

// Mock UnifiedTicketService extending the real one
class MockUnifiedTicketService extends UnifiedTicketService {
  @override
  Future<List<HuntingResult>> batchSubmitOrders({
    required List<Account> accounts,
    required Show show,
    required TicketSku sku,
    required Map<String, dynamic> params,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Simulate random success/failure
    if (params['forceSuccess'] == true) {
      return [
        HuntingResult(
          success: true,
          message: 'Success',
          orderId: 'ORDER_12345',
          timestamp: DateTime.now(),
        )
      ];
    }
    
    return [
      HuntingResult(
        success: false,
        message: 'No tickets available',
        timestamp: DateTime.now(),
      )
    ];
  }
}

void main() {
  group('TicketHunterProvider Flow Test', () {
    late TicketHunterProvider provider;
    late MockUnifiedTicketService mockService;
    late Show testShow;
    late TicketSku testSku;
    late Account testAccount;

    setUp(() {
      mockService = MockUnifiedTicketService();
      provider = TicketHunterProvider(ticketService: mockService);
      
      testSku = TicketSku(
        skuId: 'sku_1',
        name: 'VIP Ticket',
        price: 100.0,
        isEnabled: true,
      );
      
      testShow = Show(
        id: 'show_1',
        name: 'Test Concert',
        venue: 'Test Venue',
        itemId: 'item_1',
        platform: TicketPlatform.damai,
        type: ShowType.concert,
        showTime: DateTime.now().add(const Duration(days: 1)),
        saleStartTime: DateTime.now(),
        skus: [testSku],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      testAccount = Account(
        id: 'acc_1',
        username: 'test_user',
        password: 'test_password',
        platform: TicketPlatform.damai,
        cookies: {'cookie': 'test_cookie'},
        deviceId: 'device_1',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
    });

    test('Initial state should be idle', () {
      expect(provider.status, TicketHunterStatus.idle);
      expect(provider.isHunting, false);
    });

    test('Start hunting updates state to running', () async {
      // Start hunting
      final huntingFuture = provider.startHunting(
        show: testShow,
        sku: testSku,
        accounts: [testAccount],
        params: {'forceSuccess': true},
      );
      
      // Give it a moment to start
      await Future.delayed(Duration(milliseconds: 10));
      
      expect(provider.isHunting, true);
      expect(provider.status, TicketHunterStatus.running);
      
      // Wait for completion (our mock returns success immediately after delay)
      // Since startHunting loops until success/stop, and our mock returns success,
      // the loop inside startHunting should break and return.
      await huntingFuture;
      
      expect(provider.status, TicketHunterStatus.success);
      expect(provider.isHunting, false);
      expect(provider.successCount, 1);
      // Verify logs exist
      expect(provider.logs.isNotEmpty, true);
    });

    test('Stop hunting changes status to idle', () async {
      // Start a hunting that fails repeatedly
      final huntingFuture = provider.startHunting(
        show: testShow,
        sku: testSku,
        accounts: [testAccount],
        params: {'forceSuccess': false}, // Will fail loop
      );
      
      await Future.delayed(Duration(milliseconds: 50));
      expect(provider.isHunting, true);
      
      // Stop manually
      provider.stopHunting();
      
      // The loop should break and future complete
      await huntingFuture;
      
      expect(provider.isHunting, false);
      expect(provider.status, TicketHunterStatus.idle);
    });
  });
}
