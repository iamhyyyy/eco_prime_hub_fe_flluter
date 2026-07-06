import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/tier_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/customer_profile_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../auth/login_screen.dart';

// ─── Cubit ────────────────────────────────────────────────────────────────
abstract class ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileLoaded extends ProfileState {
  final UserDto user;
  final CustomerProfileDto? profile;
  ProfileLoaded(this.user, this.profile);
}
class ProfileError extends ProfileState { final String msg; ProfileError(this.msg); }

class ProfileCubit extends Cubit<ProfileState> {
  final _userRepo = UserRepository();
  final _profileRepo = CustomerProfileRepository();
  ProfileCubit() : super(ProfileLoading());

  Future<void> load(String userId) async {
    emit(ProfileLoading());
    try {
      final user = await _userRepo.getUserById(userId);
      CustomerProfileDto? profile;
      try { profile = await _profileRepo.getProfileByCustomerId(userId); } catch (_) {}
      emit(ProfileLoaded(user, profile));
    } catch (_) {
      emit(ProfileError('Không tải được thông tin'));
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit()..load(userId),
      child: _ProfileView(userId: userId),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final String userId;
  const _ProfileView({required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (ctx, state) {
        if (state is ProfileLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ProfileError) {
          return Center(child: Text(state.msg));
        }
        if (state is ProfileLoaded) {
          return _buildProfile(ctx, state.user, state.profile);
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildProfile(BuildContext ctx, UserDto user, CustomerProfileDto? profile) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF00838F)]),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (profile != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      profile.currentTier?.name ?? 'Member',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Stats row
          if (profile != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _statCard('Điểm tích lũy', '${profile.availablePoints}', Icons.stars_rounded, Colors.amber),
                  const SizedBox(width: 12),
                  _statCard('Lượt rửa', '${profile.totalVisits}', Icons.local_car_wash_rounded, Colors.blue),
                  const SizedBox(width: 12),
                  _statCard('Tổng chi', '${_fmtK(profile.totalSpending)}K', Icons.payments_rounded, Colors.green),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Info section
          _infoSection(
            title: 'Thông tin cá nhân',
            children: [
              _infoTile(Icons.person, 'Họ tên', user.fullName),
              _infoTile(Icons.email, 'Email', user.email),
              if (user.phoneNumber != null) _infoTile(Icons.phone, 'SĐT', user.phoneNumber!),
            ],
          ),

          const SizedBox(height: 16),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _actionTile(Icons.edit_rounded, 'Cập nhật thông tin', () => _showUpdateProfile(ctx, user)),
                const SizedBox(height: 8),
                _actionTile(Icons.lock_outline, 'Đổi mật khẩu', () => _showChangePassword(ctx, userId)),
                const SizedBox(height: 8),
                _actionTile(Icons.logout_rounded, 'Đăng xuất', () async {
                  await ctx.read<AuthCubit>().logout();
                  if (ctx.mounted) {
                    Navigator.of(ctx).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                }, color: Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _infoSection({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0D47A1), size: 22),
      title: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: color ?? const Color(0xFF0D47A1)),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? Colors.black87)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showUpdateProfile(BuildContext ctx, UserDto user) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _UpdateProfileSheet(
        user: user,
        onUpdated: () => ctx.read<ProfileCubit>().load(user.id),
      ),
    );
  }

  void _showChangePassword(BuildContext ctx, String userId) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(controller: oldCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu cũ', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu mới', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await UserRepository().changePassword(userId, oldCtrl.text, newCtrl.text);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công!'), backgroundColor: Colors.green));
                  }
                } catch (_) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thất bại!'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtK(double val) => (val / 1000).toStringAsFixed(0);
}

class _UpdateProfileSheet extends StatefulWidget {
  final UserDto user;
  final VoidCallback onUpdated;
  const _UpdateProfileSheet({required this.user, required this.onUpdated});

  @override
  State<_UpdateProfileSheet> createState() => _UpdateProfileSheetState();
}

class _UpdateProfileSheetState extends State<_UpdateProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _userName;
  late TextEditingController _email;
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  DateTime? _dob;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userName = TextEditingController(text: widget.user.userName);
    _email = TextEditingController(text: widget.user.email);
    _firstName = TextEditingController(text: widget.user.firstName);
    _lastName = TextEditingController(text: widget.user.lastName);
    _phone = TextEditingController(text: widget.user.phoneNumber ?? '');
    _dob = widget.user.dateOfBirth;
  }

  @override
  void dispose() {
    _userName.dispose();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final payload = {
        'userName': _userName.text,
        'email': _email.text,
        'firstName': _firstName.text,
        'lastName': _lastName.text,
        'phoneNumber': _phone.text.isEmpty ? null : _phone.text,
        'dateOfBirth': _dob?.toUtc().add(const Duration(hours: 7)).toIso8601String(),
        'isActive': widget.user.isActive,
      };
      await UserRepository().updateUser(widget.user.id, payload);
      if (mounted) {
        widget.onUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: Colors.green));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thất bại!'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Cập nhật thông tin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _firstName, decoration: const InputDecoration(labelText: 'Tên*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _lastName, decoration: const InputDecoration(labelText: 'Họ*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _userName, decoration: const InputDecoration(labelText: 'Username*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: _dob ?? DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now());
                if (date != null) setState(() => _dob = date);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Ngày sinh', border: OutlineInputBorder()),
                child: Text(_dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Chọn ngày sinh'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}
