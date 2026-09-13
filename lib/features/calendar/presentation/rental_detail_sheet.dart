import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/ios_toast.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../../costumes/domain/costume.dart';
import '../../rentals/data/rental_repository.dart';
import '../../rentals/domain/customer.dart';
import '../../rentals/domain/rental.dart';

/// Apple HIG-compliant modal sheet displaying full rental reservation details,
/// customer contact info, financial balance, and status update actions.
class RentalDetailSheet extends StatelessWidget {
  final Rental rental;
  final Customer? customer;
  final Costume? costume;
  final bool hasConflict;
  final IRentalRepository? repository;
  final VoidCallback? onRentalUpdated;

  const RentalDetailSheet({
    super.key,
    required this.rental,
    required this.customer,
    this.costume,
    this.hasConflict = false,
    this.repository,
    this.onRentalUpdated,
  });

  Widget _buildCoverPhoto(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(CupertinoIcons.sparkles, color: AppColors.primaryPink, size: 24),
        ),
      );
    }
    final cleanPath = path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
    final file = File(cleanPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(CupertinoIcons.sparkles, color: AppColors.primaryPink, size: 24),
        ),
      );
    }
    return const Center(
      child: Icon(CupertinoIcons.sparkles, color: AppColors.primaryPink, size: 24),
    );
  }

  Widget _buildItemStatusBadge(RentalItemStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case RentalItemStatus.booked:
        bg = AppColors.softPinkBg;
        fg = AppColors.primaryPink;
        label = 'Dibooking';
        break;
      case RentalItemStatus.rented:
        bg = AppColors.successMint.withValues(alpha: 0.18);
        fg = const Color(0xFF289868);
        label = 'Sedang Disewa';
        break;
      case RentalItemStatus.shipped:
        bg = AppColors.pastelPink.withValues(alpha: 0.25);
        fg = AppColors.primaryPink;
        label = 'Dikirim';
        break;
      case RentalItemStatus.returned:
        bg = const Color(0xFFE5E5EA);
        fg = const Color(0xFF3A3A3C);
        label = 'Dikembalikan';
        break;
      case RentalItemStatus.laundry:
        bg = AppColors.pastelPink.withValues(alpha: 0.18);
        fg = const Color(0xFFC44D7B);
        label = 'Dicuci';
        break;
      case RentalItemStatus.completed:
        bg = AppColors.successMint.withValues(alpha: 0.25);
        fg = const Color(0xFF1B7A4E);
        label = 'Selesai';
        break;
      case RentalItemStatus.cancelled:
        bg = AppColors.dangerRose.withValues(alpha: 0.14);
        fg = AppColors.dangerRose;
        label = 'Dibatalkan';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPaymentStatusBadge(RentalPaymentStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case RentalPaymentStatus.paid:
        bg = AppColors.successMint.withValues(alpha: 0.18);
        fg = const Color(0xFF289868);
        label = 'Lunas';
        break;
      case RentalPaymentStatus.dpPaid:
        bg = AppColors.warningOrange.withValues(alpha: 0.18);
        fg = const Color(0xFFD67710);
        label = 'DP Terbayar';
        break;
      case RentalPaymentStatus.unpaid:
        bg = AppColors.dangerRose.withValues(alpha: 0.14);
        fg = AppColors.dangerRose;
        label = 'Belum Lunas';
        break;
      case RentalPaymentStatus.refunded:
        bg = const Color(0xFFE5E5EA);
        fg = const Color(0xFF3A3A3C);
        label = 'Dikembalikan';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _confirmCancelBooking(BuildContext context) {
    final costumeName = costume?.name ?? 'kostum ini';
    final customerName = customer?.fullName ?? 'penyewa';

    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Batalkan Booking?'),
        content: Text(
          'Apakah kamu yakin ingin membatalkan jadwal sewa $costumeName untuk $customerName?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Kembali'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
              if (repository != null) {
                final updated = rental.copyWith(itemStatus: RentalItemStatus.cancelled);
                await repository!.updateRental(updated);
                onRentalUpdated?.call();
                if (context.mounted) {
                  IosToast.show(context, 'Booking berhasil dibatalkan ❌');
                }
              }
            },
            child: const Text('Batalkan Booking'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custName = customer?.fullName.isNotEmpty == true ? customer!.fullName : (rental.customerId.isNotEmpty ? rental.customerId : 'Penyewa');
    final custPhone = customer?.phone.isNotEmpty == true ? customer!.phone : '-';
    final custAddr = customer?.address.isNotEmpty == true ? customer!.address : '-';
    final custSosmed = customer?.socialMedia?.isNotEmpty == true ? customer!.socialMedia! : '-';
    final costName = costume?.name ?? (rental.costumeId.isNotEmpty ? rental.costumeId : 'Kostum');
    final costSeries = costume?.animeSeries.isNotEmpty == true ? costume!.animeSeries : 'Kostum Rental';

    final hasCover = costume?.coverPhoto != null && costume!.coverPhoto!.trim().isNotEmpty;
    final currencyFormat = NumberFormat('#,###', 'id_ID');

    final startDateFormatted = DateFormat('d MMM yyyy', 'id_ID').format(rental.startDate);
    final endDateFormatted = DateFormat('d MMM yyyy', 'id_ID').format(rental.endDate);

    final sisaTagihan = (rental.totalPrice - rental.dpAmount).clamp(0.0, double.infinity);

    return DraggableSheetContainer(
      backgroundColor: AppColors.background,
      onDismissed: () => Navigator.of(context).pop(),
      builder: (sheetCtx) => DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          fontFamily: '.SF Pro Text',
          color: AppColors.textDark,
        ),
        child: CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          navigationBar: CupertinoNavigationBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.background,
            border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
            middle: const Text('Detail Rental', style: AppTypography.navTitle),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Tutup',
                style: TextStyle(
                  color: AppColors.primaryPink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 180),
              children: [
                // 1. Hero Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasConflict ? AppColors.dangerRose : AppColors.borderSubtle,
                        width: hasConflict ? 1.5 : 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasConflict)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.dangerRose.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 14, color: AppColors.dangerRose),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Konflik Jadwal: Tanggal booking bentrok dengan sewa lain!',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dangerRose),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: AppColors.softPinkBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderSubtle, width: 0.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13.5),
                                child: hasCover
                                    ? _buildCoverPhoto(costume!.coverPhoto!)
                                    : const Center(
                                        child: Icon(
                                          CupertinoIcons.sparkles,
                                          color: AppColors.primaryPink,
                                          size: 26,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    costName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    costSeries,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _buildItemStatusBadge(rental.itemStatus),
                                      _buildPaymentStatusBadge(rental.paymentStatus),
                                      if (rental.purpose.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.borderSubtle, width: 0.5),
                                          ),
                                          child: Text(
                                            rental.purpose,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.calendar, size: 15, color: AppColors.primaryPink),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$startDateFormatted – $endDateFormatted',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.softPinkBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${rental.durationDays} Hari',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryPink),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Customer Information Section
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'INFORMASI PENYEWA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.5,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.person_fill,
                        color: AppColors.primaryPink,
                      ),
                      title: Text(
                        custName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: const Text('Nama Lengkap Penyewa', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.phone_fill,
                        color: Color(0xFF34C759),
                      ),
                      title: Text(
                        custPhone,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: const Text('Nomor WhatsApp / HP', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                      trailing: (custPhone != '-')
                          ? CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              color: AppColors.softPinkBg,
                              borderRadius: BorderRadius.circular(8),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: custPhone));
                                IosToast.show(context, 'Nomor HP disalin ke clipboard 📋');
                              },
                              child: const Text(
                                'Salin',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryPink),
                              ),
                            )
                          : null,
                    ),
                    if (customer?.parentPhone != null && customer!.parentPhone!.trim().isNotEmpty)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.person_2_fill,
                          color: Color(0xFF5856D6),
                        ),
                        title: Text(
                          customer!.parentPhone!,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        subtitle: const Text('Nomor HP Orang Tua', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                        trailing: CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          color: AppColors.softPinkBg,
                          borderRadius: BorderRadius.circular(8),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: customer!.parentPhone!));
                            IosToast.show(context, 'Nomor HP ortu disalin 📋');
                          },
                          child: const Text(
                            'Salin',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryPink),
                          ),
                        ),
                      ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.at,
                        color: Color(0xFFAF52DE),
                      ),
                      title: Text(
                        custSosmed,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                      ),
                      subtitle: const Text('Akun Media Sosial', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.location_fill,
                        color: Color(0xFFFF9500),
                      ),
                      title: Text(
                        custAddr,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      subtitle: const Text('Alamat Pengiriman / Domisili', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                    ),
                  ],
                ),

                // 3. Billing & Payment Section
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'RINCIAN BIAYA & PEMBAYARAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.5,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.money_dollar_circle_fill,
                        color: Color(0xFFFF9500),
                      ),
                      title: const Text('Total Biaya Sewa', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      subtitle: Text('Tarif sewa untuk ${rental.durationDays} hari', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                      trailing: Text(
                        'Rp ${currencyFormat.format(rental.totalPrice.toInt())}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primaryPink),
                      ),
                    ),
                    if (rental.dpAmount > 0)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.checkmark_seal_fill,
                          color: Color(0xFF34C759),
                        ),
                        title: const Text('Uang Muka (DP)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        subtitle: const Text('Pembayaran awal yang telah diterima', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                        trailing: Text(
                          'Rp ${currencyFormat.format(rental.dpAmount.toInt())}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF289868)),
                        ),
                      ),
                    if (rental.dpAmount > 0 && rental.paymentStatus != RentalPaymentStatus.paid)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.hourglass,
                          color: AppColors.dangerRose,
                        ),
                        title: const Text('Sisa Tagihan Pelunasan', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        subtitle: const Text('Perlu dilunasi saat serah terima kostum', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                        trailing: Text(
                          'Rp ${currencyFormat.format(sisaTagihan.toInt())}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.dangerRose),
                        ),
                      ),
                    if (rental.notes != null && rental.notes!.trim().isNotEmpty)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.doc_text_fill,
                          color: Color(0xFF8E8E93),
                        ),
                        title: Text(
                          rental.notes!,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.textDark),
                        ),
                        subtitle: const Text('Catatan Tambahan', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                      ),
                  ],
                ),

                // 4. Actions & Status Management
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'KELOLA STATUS RENTAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.5,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  children: [
                    // Aksi 1: Tandai Sedang Disewa
                    if (rental.itemStatus != RentalItemStatus.rented &&
                        rental.itemStatus != RentalItemStatus.returned &&
                        rental.itemStatus != RentalItemStatus.completed &&
                        rental.itemStatus != RentalItemStatus.cancelled)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.bag_fill,
                          color: Color(0xFF34C759),
                        ),
                        title: const Text(
                          'Tandai Sedang Disewa',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1E824C)),
                        ),
                        subtitle: const Text('Kostum telah diserahkan atau dikirim ke penyewa', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                        trailing: const Icon(CupertinoIcons.checkmark_alt, size: 18, color: Color(0xFF289868)),
                        onTap: () async {
                          Navigator.pop(context);
                          if (repository != null) {
                            final updated = rental.copyWith(itemStatus: RentalItemStatus.rented);
                            await repository!.updateRental(updated);
                            onRentalUpdated?.call();
                            if (context.mounted) {
                              IosToast.show(context, 'Status rental diubah ke "Sedang Disewa" ✨');
                            }
                          }
                        },
                      ),

                    // Aksi 2: Tandai Sudah Dikembalikan
                    if (rental.itemStatus != RentalItemStatus.returned &&
                        rental.itemStatus != RentalItemStatus.completed &&
                        rental.itemStatus != RentalItemStatus.cancelled)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.arrow_left_circle_fill,
                          color: AppColors.primaryPink,
                        ),
                        title: const Text(
                          'Tandai Sudah Dikembalikan',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.primaryPink),
                        ),
                        subtitle: const Text('Kostum telah diterima kembali dari penyewa', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                        trailing: const Icon(CupertinoIcons.checkmark_alt, size: 18, color: AppColors.primaryPink),
                        onTap: () async {
                          Navigator.pop(context);
                          if (repository != null) {
                            final updated = rental.copyWith(itemStatus: RentalItemStatus.returned);
                            await repository!.updateRental(updated);
                            onRentalUpdated?.call();
                            if (context.mounted) {
                              IosToast.show(context, 'Status rental diubah ke "Sudah Dikembalikan" ✨');
                            }
                          }
                        },
                      ),

                    // Aksi 3: Tandai Pembayaran Lunas
                    if (rental.paymentStatus != RentalPaymentStatus.paid &&
                        rental.itemStatus != RentalItemStatus.cancelled)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.creditcard_fill,
                          color: Color(0xFF289868),
                        ),
                        title: const Text(
                          'Tandai Pembayaran Lunas',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF289868)),
                        ),
                        subtitle: const Text('Catat bahwa seluruh biaya sewa telah dilunasi', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                        trailing: const Icon(CupertinoIcons.checkmark_alt, size: 18, color: Color(0xFF289868)),
                        onTap: () async {
                          Navigator.pop(context);
                          if (repository != null) {
                            final updated = rental.copyWith(paymentStatus: RentalPaymentStatus.paid);
                            await repository!.updateRental(updated);
                            onRentalUpdated?.call();
                            if (context.mounted) {
                              IosToast.show(context, 'Pembayaran rental berhasil ditandai Lunas ✨');
                            }
                          }
                        },
                      ),

                    // Aksi 4: Batalkan Booking (Membuka dialog konfirmasi)
                    if (rental.itemStatus != RentalItemStatus.cancelled &&
                        rental.itemStatus != RentalItemStatus.completed)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.xmark_circle_fill,
                          color: AppColors.dangerRose,
                        ),
                        title: const Text(
                          'Batalkan Booking',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.dangerRose),
                        ),
                        subtitle: const Text('Buka dialog konfirmasi pembatalan reservasi ini', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                        trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                        onTap: () => _confirmCancelBooking(context),
                      ),

                    // Status Info jika sudah selesai / dibatalkan
                    if (rental.itemStatus == RentalItemStatus.cancelled)
                      const CupertinoListTile(
                        leading: SquircleIcon(
                          icon: CupertinoIcons.info_circle_fill,
                          color: Color(0xFF8E8E93),
                        ),
                        title: Text(
                          'Booking Telah Dibatalkan',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF8E8E93)),
                        ),
                        subtitle: Text('Jadwal sewa ini tidak lagi aktif', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                      ),

                    if ((rental.itemStatus == RentalItemStatus.returned ||
                            rental.itemStatus == RentalItemStatus.completed) &&
                        rental.paymentStatus == RentalPaymentStatus.paid)
                      const CupertinoListTile(
                        leading: SquircleIcon(
                          icon: CupertinoIcons.checkmark_seal_fill,
                          color: Color(0xFF34C759),
                        ),
                        title: Text(
                          'Rental Selesai & Lunas',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF289868)),
                        ),
                        subtitle: Text('Transaksi rental ini telah sukses terselesaikan', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
