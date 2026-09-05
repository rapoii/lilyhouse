import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/sync/sync_state_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/costumes/data/costume_repository.dart';
import '../../features/costumes/presentation/costume_list_screen.dart';
import '../../features/installments/data/installment_repository.dart';
import '../../features/installments/presentation/installment_list_screen.dart';
import '../../features/rentals/data/rental_repository.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final int initialIndex;
  final ICostumeRepository? costumeRepository;
  final IRentalRepository? rentalRepository;
  final IInstallmentRepository? installmentRepository;
  final bool isTestMode;

  const MainScaffold({
    super.key,
    this.initialIndex = 0,
    this.costumeRepository,
    this.rentalRepository,
    this.installmentRepository,
    this.isTestMode = false,
  });

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  late int _currentIndex;
  late final PageController _pageController;

  // Set when a page transition is triggered programmatically (either by tapping
  // a tab or releasing the dragged pill). Prevents intermediate `onPageChanged`
  // callbacks (which PageView fires while scrolling through intermediate pages)
  // from overwriting `_currentIndex` and causing the pill to flick backward.
  int? _animatingToPage;

  // Drag tracking state for the nav bar pill-indicator drag system.
  // When the user presses down on the pink pill and drags, we capture
  // the starting tab index and a VelocityTracker for release behavior.
  // While dragging, the pill position interpolates between
  // `_dragStartIndex` (0..3) and `_dragFraction` (0.0..1.0), where
  // 0.0 means "still on starting tab" and 1.0 means "fully on the next".
  // When the user presses down on the pink pill and drags, we capture
  // the starting tab index and a VelocityTracker for release behavior.
  // While dragging, the pill position interpolates between
  // `_dragStartIndex` (0..3) and `_dragFraction` (0.0..1.0), where
  // 0.0 means "still on starting tab" and 1.0 means "fully on the next".
  // The pill itself (Layer 2) is the only widget that moves under the
  // finger — the page body (Layer 3) does not change until release.
  int? _dragStartIndex;
  double _dragFraction = 0.0;
  VelocityTracker? _dragVelocity;

  // Width (in pixels) of the nav bar's *inner* drag area, captured by
  // the LayoutBuilder that wraps the Stack. Used to convert drag pixels
  // into "fraction of a tab slot" units so the pill clamps to the
  // nav bar's own bounds (Layer 1) regardless of screen size.
  double _navBarInnerWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);

    final List<Widget> pages = [
      widget.isTestMode && widget.costumeRepository == null
          ? const Center(child: Text('Katalog Kostum'))
          : CostumeListScreen(repository: widget.costumeRepository),
      widget.isTestMode && widget.rentalRepository == null
          ? const Center(child: Text('Kalender Rental'))
          : CalendarScreen(rentalRepository: widget.rentalRepository),
      widget.isTestMode && widget.installmentRepository == null
          ? const Center(child: Text('Cicilan'))
          : InstallmentListScreen(
              repository: widget.installmentRepository ?? InstallmentRepository(),
            ),
      _buildSettingsTab(syncState),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: RepaintBoundary(
        child: PageView(
          controller: _pageController,
          // PageSwipe physics: native flutter swipe (left/right) with rubber-band
          // spring physics on settle. Supports super-smooth interactive
          // dragging on 240Hz++ and gracefully slows on low-end devices.
          physics: const PageScrollPhysics().applyTo(
            const BouncingScrollPhysics(),
          ),
          onPageChanged: (index) {
            // When animating programmatically toward a target tab (e.g. from 0
            // to 3), PageView fires intermediate events (1, 2). Ignore them so
            // the nav pill doesn't glitch/flick through intermediate tabs.
            if (_animatingToPage != null) {
              if (index == _animatingToPage) {
                _animatingToPage = null;
              }
              return;
            }
            setState(() {
              _currentIndex = index;
            });
          },
          children: pages.map((page) => RepaintBoundary(child: page)).toList(),
        ),
      ),
      bottomNavigationBar: RepaintBoundary(
        child: _buildFloatingBottomBar(syncState),
      ),
    );
  }

  Widget _buildFloatingBottomBar(SyncState syncState) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.09),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                // Outer horizontal-drag wrapper. This wraps the whole
                // pill+items stack so the drag recognizer can compete in
                // the gesture arena against the per-item tap recognizers
                // (which live on the inner Row of nav items). On a tap
                // the tap recognizer wins (picks the tab); on a horizontal
                // drag, this drag recognizer wins and moves the pill.
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (details) {
                    _dragStartIndex = _currentIndex;
                    _dragFraction = 0.0;
                    _dragVelocity = VelocityTracker.withKind(
                      details.kind ?? PointerDeviceKind.touch,
                    );
                    _dragVelocity!.addPosition(
                      details.sourceTimeStamp ?? Duration.zero,
                      details.globalPosition,
                    );
                    setState(() {});
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_dragStartIndex == null) return;
                    _dragVelocity ??= VelocityTracker.withKind(
                      details.kind ?? PointerDeviceKind.touch,
                    );
                    _dragVelocity!.addPosition(
                      details.sourceTimeStamp ?? Duration.zero,
                      details.globalPosition,
                    );
                    final pillSlotWidth = _navBarInnerWidth / 4.0;
                    if (pillSlotWidth <= 0) return;
                    final fraction =
                        (details.primaryDelta!) / pillSlotWidth;
                    final start = _dragStartIndex!;
                    final minFraction = -start.toDouble();
                    final maxFraction = (3 - start).toDouble();
                    setState(() {
                      _dragFraction =
                          (_dragFraction + fraction).clamp(minFraction, maxFraction);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragStartIndex == null) return;
                    final velocity = _dragVelocity?.getVelocity() ??
                        Velocity.zero;
                    final target = _resolvePillReleaseTarget(velocity);
                    _animatingToPage = target;
                    setState(() {
                      _currentIndex = target;
                      _dragFraction = 0.0;
                      _dragStartIndex = null;
                      _dragVelocity = null;
                    });
                    if (_pageController.hasClients) {
                      _pageController
                          .animateToPage(
                            target,
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                          )
                          .then((_) {
                            if (mounted && _animatingToPage == target) {
                              _animatingToPage = null;
                            }
                          });
                    }
                  },
                  onHorizontalDragCancel: () {
                    setState(() {
                      _dragFraction = 0.0;
                      _dragStartIndex = null;
                      _dragVelocity = null;
                    });
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Capture nav bar's inner width (Layer 1 bounds) so
                      // the pill drag math clamps to the nav bar itself,
                      // not the full screen width.
                      _navBarInnerWidth = constraints.maxWidth;
                      return Stack(
                  children: [
                    // Single Gliding Active Pill Indicator.
                    // LAYER 2 in the user's mental model: the pink pill is a
                    // separate, draggable layer that sits on top of Layer 1
                    // (the white nav bar). The user can grab the pill with
                    // their thumb and drag it horizontally to a new tab slot
                    // (clamped to the nav bar's own inner width).
                    // Page body does NOT change until the pill is released
                    // and snaps to its destination.
                    //
                    // IMPORTANT: This is just the visual layer. The drag
                    // handler lives on the whole Stack wrapper (see below)
                    // so it can win the gesture arena against the per-item
                    // tap recognizer in the Row of nav items stacked above
                    // it. We intentionally do NOT attach a GestureDetector
                    // here — that would be shadowed by the Row's tap target.
                    AnimatedAlign(
                      duration: _dragStartIndex != null
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: _computePillAlignment(),
                      child: FractionallySizedBox(
                        widthFactor: 0.25,
                        heightFactor: 1.0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F4),
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ),
                    // Navigation Items Row + dedicated drag layer for the
                    // pill indicator. The PageView body keeps its own
                    // interactive swipe (from v1.6.6), but the nav bar
                    // has its own drag recognizer that drags ONLY the
                    // pink pill — the page won't change until release.
                    _buildSwipeableNavRow(syncState),
                  ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    _animatingToPage = index;
    setState(() {
      _currentIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (mounted && _animatingToPage == index) {
              _animatingToPage = null;
            }
          });
    }
  }

  // Continuous position of the pink pill across the 4 tab slots (0.0 .. 3.0).
  // While dragging, interpolates smoothly with finger movement in real time.
  // When idle, matches `_currentIndex`.
  double _currentPillPosition() {
    if (_dragStartIndex != null) {
      return _dragStartIndex! + _dragFraction;
    }
    return _currentIndex.toDouble();
  }

  // Compute current pill alignment. During active drag we offset
  // from `_dragStartIndex` by `_dragFraction` (0 = still on start,
  // 1 = fully slid to next tab). When idle, sit on `_currentIndex`.
  Alignment _computePillAlignment() {
    final position = _currentPillPosition();
    return Alignment(-1.0 + position * (2.0 / 3.0), 0.0);
  }

  // Decide which tab the pink pill should snap to on release.
  // - Supports multi-tab drag across the whole nav bar (Layer 1):
  //   User can drag from Katalog all the way to Pengaturan.
  // - On release, snaps to the nearest tab based on where the thumb is,
  //   with a velocity flick boost if the gesture was fast.
  int _resolvePillReleaseTarget(Velocity velocity) {
    final start = _dragStartIndex ?? _currentIndex;
    final currentPos = start + _dragFraction;
    final vx = velocity.pixelsPerSecond.dx;

    // Fast flick (> 800 px/s) pushes toward flick direction by at least 1 tab
    if (vx.abs() >= 800) {
      final flickDir = vx > 0 ? 1 : -1;
      final target = (currentPos + flickDir * 0.4).round();
      return target.clamp(0, 3);
    }

    // Normal release: snap to nearest tab slot
    return currentPos.round().clamp(0, 3);
  }

  Widget _buildSwipeableNavRow(SyncState syncState) {
    // The pill (Layer 2) carries the only drag handler in the nav bar.
    // Tab taps still work normally via _buildNavItem's GestureDetector.
    // The surrounding Row is a passive layout: it just lays out the
    // 4 nav items so their icon+label text sits on top of the pill.
    return Row(
      children: [
        _buildNavItem(
          index: 0,
          icon: CupertinoIcons.sparkles,
          label: 'Katalog',
        ),
        _buildNavItem(
          index: 1,
          icon: CupertinoIcons.calendar,
          label: 'Kalender',
        ),
        _buildNavItem(
          index: 2,
          icon: CupertinoIcons.creditcard,
          label: 'Cicilan',
        ),
        _buildNavItem(
          index: 3,
          icon: CupertinoIcons.gear_alt,
          label: 'Pengaturan',
          badge: _buildSyncBadge(syncState),
        ),
      ],
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    Widget? badge,
  }) {
    final currentPos = _currentPillPosition();
    // Distance from the pink pill's center to this tab's center (in slot units).
    final distance = (currentPos - index).abs();
    // Activation level: 1.0 when pill is directly on this tab, 0.0 when 1+ slots away.
    final targetT = (1.0 - distance).clamp(0.0, 1.0);
    final isDragging = _dragStartIndex != null;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: targetT),
            duration: isDragging
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              final color = Color.lerp(
                AppColors.textMuted,
                AppColors.primaryPink,
                t,
              )!;
              final isBold = t >= 0.5;

              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: color,
                      ),
                      if (badge != null)
                        Positioned(
                          top: -2,
                          right: -4,
                          child: badge,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSyncBadge(SyncState syncState) {
    // iOS HIG: tab bar badge only shows for ERRORs or pending action.
    // Success/idle sync status is not surfaced in the tab bar to avoid noisy false-positive notifications.
    Color? badgeColor;
    switch (syncState.status) {
      case SyncStatus.syncing:
        badgeColor = AppColors.warningOrange;
        break;
      case SyncStatus.error:
        badgeColor = AppColors.dangerRose;
        break;
      case SyncStatus.success:
      case SyncStatus.idle:
        badgeColor = null; // hide badge — sync is healthy
        break;
    }

    if (badgeColor == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }

  Widget _buildSettingsTab(SyncState syncState) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (syncState.status) {
      case SyncStatus.idle:
        if (syncState.lastSyncedAt == null && syncState.pendingCount == 0) {
          statusText = 'Siap untuk sinkronisasi';
          statusColor = AppColors.primaryPink;
          statusIcon = CupertinoIcons.cloud;
        } else {
          statusText = syncState.pendingCount > 0
              ? '${syncState.pendingCount} item menunggu'
              : 'Tersinkronisasi';
          statusColor = syncState.pendingCount > 0
              ? const Color(0xFFFF9500)
              : const Color(0xFF34C759);
          statusIcon = CupertinoIcons.cloud_fill;
        }
        break;
      case SyncStatus.syncing:
        statusText = 'Sedang menyinkronkan...';
        statusColor = AppColors.primaryPink;
        statusIcon = CupertinoIcons.arrow_2_circlepath;
        break;
      case SyncStatus.success:
        statusText = 'Sinkronisasi berhasil';
        statusColor = const Color(0xFF34C759);
        statusIcon = CupertinoIcons.checkmark_alt_circle_fill;
        break;
      case SyncStatus.error:
        statusText = 'Gagal sinkron';
        statusColor = const Color(0xFFFF3B30);
        statusIcon = CupertinoIcons.exclamationmark_circle_fill;
        break;
    }

    final formattedLastSync = syncState.lastSyncedAt != null
        ? DateFormat('d MMM yyyy, HH:mm').format(syncState.lastSyncedAt!)
        : 'Belum pernah';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS Inset Grouped background
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: AppTypography.largeTitle,
        ),
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // Section 1: CLOUD SYNC
          CupertinoListSection.insetGrouped(
            header: const Text(
              'SINKRONISASI CLOUD',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C6C70), // iOS secondary label
                letterSpacing: -0.05,
              ),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            backgroundColor: Colors.transparent,
            children: [
              CupertinoListTile(
                leading: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6.5),
                  ),
                  child: Icon(statusIcon, color: Colors.white, size: 16),
                ),
                title: const Text('Status Sinkronisasi', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                trailing: syncState.status == SyncStatus.syncing
                    ? const CupertinoActivityIndicator()
                    : const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
              ),
              CupertinoListTile(
                leading: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500),
                    borderRadius: BorderRadius.circular(6.5),
                  ),
                  child: const Icon(CupertinoIcons.tray_arrow_up_fill, color: Colors.white, size: 16),
                ),
                title: const Text('Antrean Offline', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: Text(
                  '${syncState.pendingCount} item',
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
              ),
              CupertinoListTile(
                leading: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(6.5),
                  ),
                  child: const Icon(CupertinoIcons.clock_fill, color: Colors.white, size: 16),
                ),
                title: const Text('Terakhir Sinkron', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: Text(
                  formattedLastSync,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
              ),
              CupertinoListTile(
                title: Center(
                  child: Text(
                    syncState.status == SyncStatus.syncing
                        ? 'Menyinkronkan...'
                        : 'Sinkronkan Sekarang',
                    style: const TextStyle(
                      color: AppColors.primaryPink,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                onTap: syncState.status == SyncStatus.syncing
                    ? null
                    : () => ref.read(syncStateProvider.notifier).syncNow(),
              ),
            ],
          ),

          // Section 2: INTEGRATION
          CupertinoListSection.insetGrouped(
            header: const Text(
              'INTEGRASI GOOGLE APPS SCRIPT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C6C70),
                letterSpacing: -0.05,
              ),
            ),
            footer: const Text(
              'Backend Web App gratis tanpa server, tersinkron ke Google Sheets & Google Drive.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8E8E93),
              ),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            backgroundColor: Colors.transparent,
            children: [
              CupertinoListTile(
                leading: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5856D6),
                    borderRadius: BorderRadius.circular(6.5),
                  ),
                  child: const Icon(CupertinoIcons.doc_text_fill, color: Colors.white, size: 16),
                ),
                title: const Text('Script Backend', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: const Text(
                  'google_apps_script.js',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFF8E8E93)),
                ),
                trailing: const Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: AppColors.primaryPink),
                onTap: () {
                  // iOS style subtle haptic feedback or toast
                  // (no Android bottom SnackBar)
                },
              ),
            ],
          ),

          // Section 3: ABOUT
          CupertinoListSection.insetGrouped(
            header: const Text(
              'TENTANG APLIKASI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C6C70),
                letterSpacing: -0.05,
              ),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            backgroundColor: Colors.transparent,
            children: [
              CupertinoListTile(
                leading: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPink,
                    borderRadius: BorderRadius.circular(6.5),
                  ),
                  child: const Icon(CupertinoIcons.heart_fill, color: Colors.white, size: 16),
                ),
                title: const Text('LilyHouse Rent', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: const Text('v1.0.0', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15)),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
              ),
              CupertinoListTile(
                leading: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(6.5),
                  ),
                  child: const Icon(CupertinoIcons.paintbrush_fill, color: Colors.white, size: 16),
                ),
                title: const Text('Design System', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: const Text('Apple HIG / iOS 18', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15)),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
