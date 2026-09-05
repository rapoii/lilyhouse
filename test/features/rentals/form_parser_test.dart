import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/features/rentals/data/form_parser.dart';
import 'package:lilyhouse/features/rentals/domain/parsed_rental_data.dart';

void main() {
  group('SmartFormParser & RentFormParser', () {
    const realCustomerSample = '''
🎀Form Rent Lilycosrent🎀
Pastikan kalian udah baca rules~ 
No privat akun/ganti usn selama masa rental yaa

1.  Nama asli/nama dipaket : Jihan Fatin 
2.  No HP : 082245777711
3.  Alamat lengkap : Jalan Karang Pola Dalam IV No. 10, RT.2/RW.9, Jati Padang, Pasar Minggu (Kosan Pak Erwin), KOTA JAKARTA SELATAN, PASAR MINGGU, DKI JAKARTA, ID, 12540
4.  No hp ortu/org terdekat yg bisa dihubungi : 082245777711 (ibu)
5.  Akun sosmed (tiktok,ig) : tiktok @kodzukenlucu
6.  Kostum yg dirental : Citlali
7.  Tanggal dipakai (3 hari) : 5-6 sept 2026
8.  Untuk keperluan (homecos/photoses/event/lomba) : homecos
9.  Foto Kartu identitas (KTP/KIA)
10.  Selfie memegang kartu identitas
''';

    test('accurately extracts fields from raw WhatsApp message', () {
      final result = SmartFormParser.parse(realCustomerSample);

      expect(result.fullName, equals('Jihan Fatin'));
      expect(result.phone, equals('082245777711'));
      expect(result.address, contains('Jalan Karang Pola Dalam IV'));
      expect(result.parentPhone, equals('082245777711 (ibu)'));
      expect(result.emergencyContact, equals('082245777711 (ibu)'));
      expect(result.socialMedia, equals('tiktok @kodzukenlucu'));
      expect(result.costumeName, equals('Citlali'));
      expect(result.datesRaw, equals('5-6 sept 2026'));
      expect(result.purpose, equals('homecos'));
      expect(result.isValid, isTrue);
    });

    test('RentFormParser alias works identically to SmartFormParser', () {
      final result = RentFormParser.parse(realCustomerSample);
      expect(result, isA<ParsedCustomerForm>());
      expect(result.fullName, equals('Jihan Fatin'));
      expect(result.costumeName, equals('Citlali'));
    });

    test('handles multi-line addresses properly without truncating', () {
      const multilineAddressForm = '''
1. Nama asli/nama dipaket : Anya Forger
2. No HP : 081234567890
3. Alamat lengkap : Jl. Mawar Indah Blok B3 No. 12
RT 04 / RW 05, Kelurahan Kebon Jeruk
Kecamatan Kebon Jeruk, Jakarta Barat 11530
Patokan dekat masjid Al-Hidayah
4. No hp ortu/org terdekat yg bisa dihubungi : 081298765432 (Ayah Loid)
5. Akun sosmed (tiktok,ig) : @anya_stella
6. Kostum yg dirental : Eden Academy Uniform
7. Tanggal dipakai (3 hari) : 10 - 12 Oktober 2026
8. Untuk keperluan : event Comic Frontier
''';

      final result = SmartFormParser.parse(multilineAddressForm);

      expect(result.fullName, equals('Anya Forger'));
      expect(result.phone, equals('081234567890'));
      expect(
        result.address,
        equals(
          'Jl. Mawar Indah Blok B3 No. 12 RT 04 / RW 05, Kelurahan Kebon Jeruk Kecamatan Kebon Jeruk, Jakarta Barat 11530 Patokan dekat masjid Al-Hidayah',
        ),
      );
      expect(result.parentPhone, equals('081298765432 (Ayah Loid)'));
      expect(result.socialMedia, equals('@anya_stella'));
      expect(result.costumeName, equals('Eden Academy Uniform'));
      expect(result.datesRaw, equals('10 - 12 Oktober 2026'));
      expect(result.purpose, equals('event Comic Frontier'));
    });

    test('date parsing extracts startDate and endDate for multi-day rental', () {
      final result = SmartFormParser.parse(realCustomerSample);
      expect(result.startDate, equals(DateTime(2026, 9, 5)));
      expect(result.endDate, equals(DateTime(2026, 9, 6)));
      expect(result.rentalDurationDays, equals(2));
    });

    test('date parsing handles single date format "15 September 2026"', () {
      const singleDateForm = '''
1. Nama asli/nama dipaket : Frieren
2. No HP : +62 812-3456-7890
3. Alamat lengkap : Lembah End
4. No hp ortu : -
5. Akun sosmed : @frieren_mage
6. Kostum yg dirental : Frieren Cosplay Set
7. Tanggal dipakai : 15 September 2026
8. Untuk keperluan : photoses
''';
      final result = SmartFormParser.parse(singleDateForm);
      expect(result.startDate, equals(DateTime(2026, 9, 15)));
      expect(result.endDate, equals(DateTime(2026, 9, 15)));
      expect(result.rentalDurationDays, equals(1));
    });

    test('date parsing handles date with slash or dash "2026-10-05 sd 2026-10-07"', () {
      const rangeForm = '''
1. Nama : Fern
2. No HP : 08991234567
3. Alamat : Eisen Home
4. No hp ortu : 08991234568
5. Akun sosmed : @fern
6. Kostum yg dirental : Fern Wand
7. Tanggal dipakai : 05/10/2026 - 07/10/2026
8. Untuk keperluan : event
''';
      final result = SmartFormParser.parse(rangeForm);
      expect(result.startDate, equals(DateTime(2026, 10, 5)));
      expect(result.endDate, equals(DateTime(2026, 10, 7)));
      expect(result.rentalDurationDays, equals(3));
    });

    test('handles empty or garbage input gracefully', () {
      final emptyResult = SmartFormParser.parse('');
      expect(emptyResult.fullName, isNull);
      expect(emptyResult.isValid, isFalse);

      final garbageResult = SmartFormParser.parse('Halo kak mau tanya rental');
      expect(garbageResult.fullName, isNull);
      expect(garbageResult.isValid, isFalse);
    });

    test('cleans and normalizes phone numbers cleanly', () {
      const testPhoneForm = '''
1. Nama: Test User
2. No HP: +62 822-4577-7711
3. Alamat: Jl Melati
4. No hp ortu: 0812 3456 7890 (kakak)
5. Akun sosmed: IG: @test
6. Kostum yg dirental: Test Kostum
7. Tanggal dipakai: 1 Jan 2026
8. Untuk keperluan: homecos
''';
      final result = SmartFormParser.parse(testPhoneForm);
      expect(result.normalizedPhone, equals('082245777711'));
      expect(result.fullName, equals('Test User'));
    });
  });
}
