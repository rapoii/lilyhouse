import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/features/rentals/domain/customer.dart';

void main() {
  group('Customer Model', () {
    final customer = Customer(
      id: 'cust_001',
      fullName: 'Jihan Fatin',
      phone: '082245777711',
      parentPhone: '082245777711 (ibu)',
      address: 'Jalan Karang Pola Dalam IV No. 10',
      socialMedia: 'tiktok @kodzukenlucu',
      ktpPhotoUrl: 'uploads/ktp_001.jpg',
      selfieKtpUrl: 'uploads/selfie_001.jpg',
      syncStatus: 'synced',
    );

    test('instantiates with all fields properly', () {
      expect(customer.id, 'cust_001');
      expect(customer.fullName, 'Jihan Fatin');
      expect(customer.phone, '082245777711');
      expect(customer.parentPhone, '082245777711 (ibu)');
      expect(customer.address, 'Jalan Karang Pola Dalam IV No. 10');
      expect(customer.socialMedia, 'tiktok @kodzukenlucu');
      expect(customer.ktpPhotoUrl, 'uploads/ktp_001.jpg');
      expect(customer.selfieKtpUrl, 'uploads/selfie_001.jpg');
      expect(customer.syncStatus, 'synced');
    });

    test('toSqlite converts customer to database map properly', () {
      final map = customer.toSqlite();
      expect(map['id'], 'cust_001');
      expect(map['full_name'], 'Jihan Fatin');
      expect(map['phone'], '082245777711');
      expect(map['parent_phone'], '082245777711 (ibu)');
      expect(map['address'], 'Jalan Karang Pola Dalam IV No. 10');
      expect(map['social_media'], 'tiktok @kodzukenlucu');
      expect(map['ktp_photo_url'], 'uploads/ktp_001.jpg');
      expect(map['selfie_ktp_url'], 'uploads/selfie_001.jpg');
      expect(map['sync_status'], 'synced');
    });

    test('fromSqlite parses database map into Customer model', () {
      final map = {
        'id': 'cust_002',
        'full_name': 'Alya Sakura',
        'phone': '081234567890',
        'parent_phone': null,
        'address': 'Bandung No. 12',
        'social_media': '@alyacos',
        'ktp_photo_url': null,
        'selfie_ktp_url': null,
        'sync_status': 'pending',
      };

      final parsed = Customer.fromSqlite(map);
      expect(parsed.id, 'cust_002');
      expect(parsed.fullName, 'Alya Sakura');
      expect(parsed.phone, '081234567890');
      expect(parsed.parentPhone, isNull);
      expect(parsed.address, 'Bandung No. 12');
      expect(parsed.socialMedia, '@alyacos');
      expect(parsed.ktpPhotoUrl, isNull);
      expect(parsed.selfieKtpUrl, isNull);
      expect(parsed.syncStatus, 'pending');
    });

    test('copyWith updates specific fields correctly', () {
      final updated = customer.copyWith(
        phone: '089999999999',
        syncStatus: 'pending',
      );
      expect(updated.id, customer.id);
      expect(updated.fullName, customer.fullName);
      expect(updated.phone, '089999999999');
      expect(updated.syncStatus, 'pending');
    });
  });
}
