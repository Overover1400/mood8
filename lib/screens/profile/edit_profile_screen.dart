import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/haptic_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _bio = TextEditingController();
  bool _showWellbeing = false;
  bool _bioSaving = false;
  bool _avatarUploading = false;
  String? _avatarUrl;
  String? _bioRejection;

  @override
  void initState() {
    super.initState();
    final me = AuthService().currentUser;
    if (me != null) {
      _bio.text = me.bio ?? '';
      _showWellbeing = me.showWellbeingPublic;
      _avatarUrl = me.avatarAbsoluteUrl();
    }
    // Refresh /me in the background so cached values get freshened.
    // ignore: discarded_futures
    AuthService().refreshMe().then((_) {
      if (!mounted) return;
      final u = AuthService().currentUser;
      if (u == null) return;
      setState(() {
        if (_bio.text.isEmpty) _bio.text = u.bio ?? '';
        _showWellbeing = u.showWellbeingPublic;
        _avatarUrl = u.avatarAbsoluteUrl();
      });
    });
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_avatarUploading) return;
    HapticService().light();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (picked == null) return;
      setState(() => _avatarUploading = true);
      final bytes = await picked.readAsBytes();
      await ProfileService().uploadAvatar(
        bytes: bytes,
        filename: picked.name,
      );
      // Pull fresh /me so the AuthUser cache picks up the new URL.
      await AuthService().refreshMe();
      if (!mounted) return;
      setState(() {
        _avatarUrl = AuthService().currentUser?.avatarAbsoluteUrl();
        _avatarUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _avatarUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              e is ProfileError ? e.message : 'Could not upload that image.'),
        ),
      );
    }
  }

  Future<void> _saveBio() async {
    if (_bioSaving) return;
    setState(() {
      _bioSaving = true;
      _bioRejection = null;
    });
    HapticService().selection();
    try {
      final result = await ProfileService().update(bio: _bio.text);
      if (!mounted) return;
      if (result['saved'] == false) {
        setState(() {
          _bioRejection =
              result['reason'] as String? ?? 'Please clean up the bio.';
          _bioSaving = false;
        });
        return;
      }
      await AuthService().refreshMe();
      if (!mounted) return;
      setState(() => _bioSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _bioSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ProfileError ? e.message : 'Could not save.',
        )),
      );
    }
  }

  Future<void> _toggleWellbeing(bool value) async {
    HapticService().selection();
    setState(() => _showWellbeing = value);
    try {
      await ProfileService().update(showWellbeingPublic: value);
      await AuthService().refreshMe();
    } catch (e) {
      if (!mounted) return;
      setState(() => _showWellbeing = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ProfileError ? e.message : 'Could not save that toggle.',
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded,
                        color: BrandColors.inkSoft(context)),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Edit profile',
                      style: brandFont(
                        color: BrandColors.ink(context),
                        fontSize: 26,
                        weight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.orbGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.pink.withValues(alpha: 0.40),
                              blurRadius: 22,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _avatarUrl != null
                              ? Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _AvatarInitial(name: user?.name ?? '?'),
                                )
                              : _AvatarInitial(name: user?.name ?? '?'),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.pink.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: _avatarUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Tap to change avatar',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _SectionLabel('BIO'),
              const SizedBox(height: 8),
              TextField(
                controller: _bio,
                maxLines: 4,
                maxLength: 200,
                style: TextStyle(color: BrandColors.ink(context)),
                decoration: InputDecoration(
                  hintText:
                      'A short line about who you are or what you’re working on.',
                  hintMaxLines: 2,
                  hintStyle: TextStyle(
                    color: BrandColors.inkFaint(context).withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor:
                      BrandColors.bgCard(context).withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.purple.withValues(alpha: 0.30),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.purple.withValues(alpha: 0.30),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.pinkLight,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (_bioRejection != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: AppColors.pink.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.pinkLight.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.pinkLight, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _bioRejection!,
                          style: TextStyle(
                            color: BrandColors.ink(context),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _bioSaving ? null : _saveBio,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      _bioSaving ? 'Saving…' : 'Save bio',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _SectionLabel('WELLBEING ON PUBLIC PROFILE'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                decoration: BoxDecoration(
                  color: BrandColors.bgCard(context).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.purple.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show my wellbeing on my profile',
                            style: TextStyle(
                              color: BrandColors.ink(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Other users will see a soft 7-day average mood — not your individual check-ins. Off by default.',
                            style: TextStyle(
                              color: BrandColors.inkSoft(context),
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _showWellbeing,
                      activeThumbColor: AppColors.pinkLight,
                      onChanged: _toggleWellbeing,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: BrandColors.inkDim(context),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 48,
        ),
      ),
    );
  }
}
