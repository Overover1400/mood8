import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/device_link_service.dart';
import '../services/haptic_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'link_device_screen.dart';

/// Settings → "Sync across devices". Real sync status (last synced), a
/// manual "Sync now" action with feedback, and the list of linked
/// standalone devices (watches) with an unlink option. Replaces the old
/// "coming soon" placeholder.
class SyncDevicesScreen extends StatefulWidget {
  const SyncDevicesScreen({super.key});

  @override
  State<SyncDevicesScreen> createState() => _SyncDevicesScreenState();
}

class _SyncDevicesScreenState extends State<SyncDevicesScreen> {
  DateTime? _lastSync;
  List<LinkedDevice> _devices = const [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final last = await SyncService().lastSyncAt();
    final devices = await DeviceLinkService().listDevices();
    if (!mounted) return;
    setState(() {
      _lastSync = last;
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    HapticService().light();
    setState(() => _syncing = true);
    final ok = await SyncService().manualSync();
    if (!mounted) return;
    setState(() => _syncing = false);
    if (ok) {
      HapticService().reward();
      await _load();
      _snack('Synced just now', ok: true);
    } else {
      HapticService().medium();
      _snack("Couldn't sync — check your connection.", ok: false);
    }
  }

  Future<void> _unlink(LinkedDevice d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Unlink device?',
            style: TextStyle(color: BrandColors.ink(context))),
        content: Text(
          'This ${d.name ?? 'device'} will be signed out and stop syncing. '
          'You can link it again anytime with a new code.',
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unlink',
                style: TextStyle(color: Color(0xFFFF6B81))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    HapticService().medium();
    final ok = await DeviceLinkService().unlinkDevice(d.id);
    if (!mounted) return;
    if (ok) {
      await _load();
      _snack('Device unlinked', ok: true);
    } else {
      _snack("Couldn't unlink — try again.", ok: false);
    }
  }

  void _snack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: BrandColors.bgCard(context),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _relative(DateTime? t) {
    if (t == null) return 'Never';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: BrandColors.inkSoft(context), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Sync across devices',
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // ── Sync status + Sync now ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: BrandColors.bgCard(context).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_done_outlined,
                              color: AppColors.pinkLight, size: 20),
                          const SizedBox(width: 10),
                          Text('Cloud sync',
                              style: GoogleFonts.bricolageGrotesque(
                                color: BrandColors.ink(context),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _loading
                            ? 'Checking…'
                            : 'Last synced: ${_relative(_lastSync)}',
                        style: TextStyle(
                          color: BrandColors.inkSoft(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _syncing ? null : _syncNow,
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppColors.buttonGradient,
                            borderRadius: BorderRadius.circular(23),
                          ),
                          child: _syncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Sync now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  )),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── Linked devices ──────────────────────────────────
                Text('LINKED DEVICES',
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    )),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_devices.isEmpty)
                  _EmptyDevices()
                else
                  ..._devices.map((d) => _DeviceTile(
                        device: d,
                        onUnlink: () => _unlink(d),
                      )),
                const SizedBox(height: 16),
                // Connect-a-watch entry (also lives in Settings → Devices).
                GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const LinkDeviceScreen()));
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded,
                            color: AppColors.pinkLight, size: 20),
                        const SizedBox(width: 10),
                        Text('Connect a watch',
                            style: TextStyle(
                              color: BrandColors.ink(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onUnlink});
  final LinkedDevice device;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.watch_outlined,
              color: BrandColors.inkSoft(context), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              device.name ?? device.deviceType,
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onUnlink,
            child: const Text('Unlink',
                style: TextStyle(
                    color: Color(0xFFFF6B81), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'No devices linked yet. Link your Wear OS watch to check in from '
        'your wrist.',
        style: TextStyle(
          color: BrandColors.inkDim(context),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}
