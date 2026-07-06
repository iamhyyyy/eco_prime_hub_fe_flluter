import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../auth/login_screen.dart';

// ─── Cubits ───────────────────────────────────────────────────────────────

abstract class ManagerBookingState {}
class ManagerBookingLoading extends ManagerBookingState {}
class ManagerBookingLoaded extends ManagerBookingState {
  final List<BookingDto> all;
  final List<BookingDto> pending;
  final List<BookingDto> inProgress;
  ManagerBookingLoaded(this.all)
      : pending = all.where((b) => b.status == BookingStatus.pending).toList(),
        inProgress = all.where((b) => b.status == BookingStatus.inProgress || b.status == BookingStatus.confirmed).toList();
}
class ManagerBookingError extends ManagerBookingState { final String msg; ManagerBookingError(this.msg); }

class ManagerBookingCubit extends Cubit<ManagerBookingState> {
  final _repo = BookingRepository();
  ManagerBookingCubit() : super(ManagerBookingLoading());

  Future<void> load() async {
    emit(ManagerBookingLoading());
    try {
      final list = await _repo.getAllBookings();
      list.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      emit(ManagerBookingLoaded(list));
    } catch (_) {
      emit(ManagerBookingError('Không tải được booking'));
    }
  }

  Future<void> confirm(String id) async {
    await _repo.updateBookingStatus(id, BookingStatus.confirmed.index);
    load();
  }

  Future<void> checkin(String id) async {
    await _repo.checkinBooking(id);
    load();
  }

  Future<void> complete(String id) async {
    await _repo.completeBooking(id);
    load();
  }
}

// ─── Manager User Cubit ───
abstract class ManagerUserState {}
class ManagerUserLoading extends ManagerUserState {}
class ManagerUserLoaded extends ManagerUserState {
  final List<UserDto> users;
  ManagerUserLoaded(this.users);
}
class ManagerUserError extends ManagerUserState { final String msg; ManagerUserError(this.msg); }

class ManagerUserCubit extends Cubit<ManagerUserState> {
  final _userRepo = UserRepository();
  ManagerUserCubit() : super(ManagerUserLoading());

  Future<void> load() async {
    emit(ManagerUserLoading());
    try {
      final users = await _userRepo.getAllUsers();
      emit(ManagerUserLoaded(users));
    } catch (_) {
      emit(ManagerUserError('Không tải được danh sách người dùng'));
    }
  }

  Future<void> lockUser(String id) async {
    await _userRepo.lockUser(id);
    load();
  }

  Future<void> unlockUser(String id) async {
    await _userRepo.unlockUser(id);
    load();
  }

  Future<void> createUser(CreateUserDto dto) async {
    try {
      await _userRepo.createUser(dto);
      load();
    } catch (_) {
      emit(ManagerUserError('Không thể tạo người dùng'));
    }
  }
}


// ─── Main Screen ──────────────────────────────────────────────────────────
class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});
  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ManagerBookingCubit()..load()),
        BlocProvider(create: (_) => ManagerUserCubit()..load()),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF004D40),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Manager Panel', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            Builder(builder: (ctx) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (_selectedIndex == 0) ctx.read<ManagerBookingCubit>().load();
                if (_selectedIndex == 1) ctx.read<ManagerUserCubit>().load();
              },
            )),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await context.read<AuthCubit>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            _ManagerBookingsPage(),
            _ManagerUsersPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF004D40).withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Bookings'),
            NavigationDestination(icon: Icon(Icons.people_rounded), label: 'Users'),
          ],
        ),
        floatingActionButton: _selectedIndex == 1
            ? FloatingActionButton.extended(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Thêm User'),
                onPressed: () => _showAddUserDialog(context),
              )
            : null,
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddUserDialog(
        onSubmit: (dto) => context.read<ManagerUserCubit>().createUser(dto),
      ),
    );
  }
}

// ─── Bookings Page ────────────────────────────────────────────────────────
class _ManagerBookingsPage extends StatefulWidget {
  const _ManagerBookingsPage();
  @override
  State<_ManagerBookingsPage> createState() => _ManagerBookingsPageState();
}

class _ManagerBookingsPageState extends State<_ManagerBookingsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF004D40),
            child: TabBar(
              onTap: (i) => setState(() => _tab = i),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'Tất cả'),
                Tab(text: 'Chờ xử lý'),
                Tab(text: 'Đang làm'),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<ManagerBookingCubit, ManagerBookingState>(
              builder: (ctx, state) {
                if (state is ManagerBookingLoading) return const Center(child: CircularProgressIndicator());
                if (state is ManagerBookingError) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(state.msg, style: const TextStyle(color: Colors.grey)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                        onPressed: () => ctx.read<ManagerBookingCubit>().load(),
                      ),
                    ],
                  ));
                }
                if (state is ManagerBookingLoaded) {
                  final lists = [state.all, state.pending, state.inProgress];
                  final bookings = lists[_tab];
                  if (bookings.isEmpty) return const Center(child: Text('Không có booking nào', style: TextStyle(color: Colors.grey, fontSize: 16)));
                  return RefreshIndicator(
                    onRefresh: () => ctx.read<ManagerBookingCubit>().load(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (_, i) => _ManagerBookingCard(booking: bookings[i]),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Users Page ───────────────────────────────────────────────────────────
class _ManagerUsersPage extends StatelessWidget {
  const _ManagerUsersPage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ManagerUserCubit, ManagerUserState>(
      builder: (ctx, state) {
        if (state is ManagerUserLoading) return const Center(child: CircularProgressIndicator());
        if (state is ManagerUserError) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(state.msg),
              ElevatedButton(onPressed: () => ctx.read<ManagerUserCubit>().load(), child: const Text('Thử lại')),
            ],
          ));
        }
        if (state is ManagerUserLoaded) {
          if (state.users.isEmpty) return const Center(child: Text('Không có người dùng nào', style: TextStyle(color: Colors.grey)));
          return RefreshIndicator(
            onRefresh: () => ctx.read<ManagerUserCubit>().load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.users.length,
              itemBuilder: (ctx, i) {
                final u = state.users[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                  child: ListTile(
                    onTap: () => _showUserDetailsDialog(context, u),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.1),
                      child: Text(u.firstName.isNotEmpty ? u.firstName[0] : '?', style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(u.email, style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: u.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(u.isActive ? 'Active' : 'Locked', style: TextStyle(color: u.isActive ? Colors.green : Colors.red, fontSize: 11)),
                        ),
                        IconButton(
                          icon: Icon(u.isActive ? Icons.lock_outline : Icons.lock_open, size: 20, color: u.isActive ? Colors.red : Colors.green),
                          onPressed: () {
                            if (u.isActive) ctx.read<ManagerUserCubit>().lockUser(u.id);
                            else ctx.read<ManagerUserCubit>().unlockUser(u.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  void _showUserDetailsDialog(BuildContext context, UserDto user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chi tiết người dùng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${user.id}'),
            const SizedBox(height: 8),
            Text('Username: ${user.userName}'),
            const SizedBox(height: 8),
            Text('Họ và tên: ${user.fullName}'),
            const SizedBox(height: 8),
            Text('Email: ${user.email}'),
            const SizedBox(height: 8),
            Text('Số điện thoại: ${user.phoneNumber ?? "Trống"}'),
            const SizedBox(height: 8),
            Text('Ngày sinh: ${user.dateOfBirth != null ? "${user.dateOfBirth!.day}/${user.dateOfBirth!.month}/${user.dateOfBirth!.year}" : "Trống"}'),
            const SizedBox(height: 8),
            Text('Trạng thái: ${user.isActive ? "Đang hoạt động" : "Bị khoá"}'),
            const SizedBox(height: 8),
            Text('Vai trò: ${user.role ?? "N/A"}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }
}

class _ManagerBookingCard extends StatelessWidget {
  final BookingDto booking;
  const _ManagerBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(booking.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Booking #${booking.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.$2.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusInfo.$1, style: TextStyle(color: statusInfo.$2, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${booking.scheduledTime.day}/${booking.scheduledTime.month}/${booking.scheduledTime.year}  ${booking.scheduledTime.hour.toString().padLeft(2, '0')}:${booking.scheduledTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (booking.status == BookingStatus.pending) ...[
                  Expanded(
                    child: _actionBtn(context, 'Xác nhận', Colors.blue,
                        () => context.read<ManagerBookingCubit>().confirm(booking.id)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (booking.status == BookingStatus.confirmed) ...[
                  Expanded(
                    child: _actionBtn(context, 'Check-in', Colors.purple,
                        () => context.read<ManagerBookingCubit>().checkin(booking.id)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (booking.status == BookingStatus.inProgress) ...[
                  Expanded(
                    child: _actionBtn(context, 'Hoàn thành ✓', Colors.green,
                        () => context.read<ManagerBookingCubit>().complete(booking.id)),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(BuildContext ctx, String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  (String, Color) _statusInfo(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending:    return ('Chờ xác nhận', Colors.orange);
      case BookingStatus.confirmed:  return ('Đã xác nhận', Colors.blue);
      case BookingStatus.inProgress: return ('Đang thực hiện', Colors.purple);
      case BookingStatus.completed:  return ('Hoàn thành', Colors.green);
      case BookingStatus.cancelled:  return ('Đã huỷ', Colors.red);
      case BookingStatus.noShow:     return ('Không đến', Colors.grey);
    }
  }
}

class _AddUserDialog extends StatefulWidget {
  final Function(CreateUserDto) onSubmit;
  const _AddUserDialog({required this.onSubmit});
  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _dob;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm người dùng'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _userName, decoration: const InputDecoration(labelText: 'Tên đăng nhập (Username)*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _password, decoration: const InputDecoration(labelText: 'Mật khẩu*'), obscureText: true, validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _firstName, decoration: const InputDecoration(labelText: 'Tên*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _lastName, decoration: const InputDecoration(labelText: 'Họ*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now());
                  if (date != null) setState(() => _dob = date);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày sinh', border: OutlineInputBorder()),
                  child: Text(_dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Chọn ngày sinh'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSubmit(CreateUserDto(
                userName: _userName.text,
                email: _email.text,
                password: _password.text,
                firstName: _firstName.text,
                lastName: _lastName.text,
                phoneNumber: _phone.text.isEmpty ? null : _phone.text,
                dateOfBirth: _dob,
              ));
              Navigator.pop(context);
            }
          },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

