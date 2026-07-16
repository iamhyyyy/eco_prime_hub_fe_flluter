import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../auth/login_screen.dart';
import 'manage_services/ManageServicesScreen.dart';
import 'promotion_services/ManagePromotionsScreen.dart';

// Import các màn hình quản lý (Hãy đảm bảo đường dẫn này khớp với project của bạn)

// import 'manage_tiers/manage_tiers_screen.dart'; // Mở comment khi bạn tạo xong file này
// import 'manage_pointlogs/manage_pointlogs_screen.dart'; // Mở comment khi bạn tạo xong file này

// ─── Cubit ────────────────────────────────────────────────────────────────
abstract class AdminState {}
class AdminLoading extends AdminState {}
class AdminLoaded extends AdminState {
  final List<UserDto> users;
  final List<BookingDto> bookings;
  AdminLoaded(this.users, this.bookings);
}
class AdminError extends AdminState { final String msg; AdminError(this.msg); }

class AdminCubit extends Cubit<AdminState> {
  final _userRepo = UserRepository();
  final _bookingRepo = BookingRepository();
  AdminCubit() : super(AdminLoading());

  Future<void> load() async {
    emit(AdminLoading());
    try {
      final results = await Future.wait([_userRepo.getAllUsers(), _bookingRepo.getAllBookings()]);
      emit(AdminLoaded(results[0] as List<UserDto>, results[1] as List<BookingDto>));
    } catch (_) {
      emit(AdminError('Không tải được dữ liệu'));
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
}

// ─── Screen ───────────────────────────────────────────────────────────────
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminCubit()..load(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            Builder(builder: (ctx) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ctx.read<AdminCubit>().load(),
            )),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await context.read<AuthCubit>().logout();
                if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              },
            ),
          ],
        ),
        body: BlocBuilder<AdminCubit, AdminState>(
          builder: (ctx, state) {
            if (state is AdminLoading) return const Center(child: CircularProgressIndicator());
            if (state is AdminError) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(state.msg),
              ElevatedButton(onPressed: () => ctx.read<AdminCubit>().load(), child: const Text('Thử lại')),
            ]));
            }
            if (state is AdminLoaded) {
              return IndexedStack(
                index: _selectedIndex,
                children: [
                  _DashboardPage(users: state.users, bookings: state.bookings),
                  _UsersPage(users: state.users),
                  _BookingsPage(bookings: state.bookings),
                ],
              );
            }
            return const SizedBox();
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF1A237E).withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.people_rounded), label: 'Users'),
            NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Bookings'),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Page ────────────────────────────────────────────────────────
class _DashboardPage extends StatelessWidget {
  final List<UserDto> users;
  final List<BookingDto> bookings;
  const _DashboardPage({required this.users, required this.bookings});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayBookings = bookings.where((b) =>
    b.scheduledTime.day == today.day &&
        b.scheduledTime.month == today.month &&
        b.scheduledTime.year == today.year).toList();
    final revenue = bookings.where((b) => b.status == BookingStatus.completed).fold(0.0, (sum, b) => sum + b.finalAmount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng quan hệ thống', style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 4),
                Text('Eco Prime Hub', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Công cụ quản lý', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          // ─── CÁC NÚT ĐIỀU HƯỚNG TASK CỦA BẠN NẰM Ở ĐÂY ───
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2, // Tỷ lệ này giúp nút bấm dẹp hơn, nhìn giống nút menu
            children: [
              _ActionCard('Dịch vụ', Icons.local_car_wash, Colors.blue, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageServicesScreen()));
              }),
              _ActionCard('Khuyến mãi', Icons.discount, Colors.purple, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePromotionsScreen()));
              }),
              _ActionCard('Hạng thành viên', Icons.workspace_premium, Colors.orange, () {
                // Tạm thời hiển thị thông báo, thay bằng Navigator khi code xong file
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đang phát triển')));
                // Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageTiersScreen()));
              }),
              _ActionCard('Điểm thưởng', Icons.stars, Colors.green, () {
                // Tạm thời hiển thị thông báo
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đang phát triển')));
                // Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePointLogScreen()));
              }),
            ],
          ),

          const SizedBox(height: 24),
          const Text('Thống kê nhanh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard('Tổng Users', '${users.length}', Icons.people_rounded, const Color(0xFF1565C0)),
              _StatCard('Booking hôm nay', '${todayBookings.length}', Icons.calendar_today_rounded, const Color(0xFF2E7D32)),
              _StatCard('Tổng Booking', '${bookings.length}', Icons.receipt_long_rounded, const Color(0xFF6A1B9A)),
              _StatCard('Doanh thu', '${_fmtM(revenue)}M', Icons.attach_money_rounded, const Color(0xFFE65100)),
            ],
          ),

          const SizedBox(height: 24),
          const Text('Booking gần đây', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...bookings.take(5).map((b) => _MiniBookingRow(b)),
        ],
      ),
    );
  }

  String _fmtM(double val) => (val / 1_000_000).toStringAsFixed(1);
}

// Widget mới dùng cho các nút quản lý (Có chức năng ấn được - InkWell)
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(this.title, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 13),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MiniBookingRow extends StatelessWidget {
  final BookingDto booking;
  const _MiniBookingRow(this.booking);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(child: Text('#${booking.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Text('${booking.scheduledTime.day}/${booking.scheduledTime.month}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Users Page ────────────────────────────────────────────────────────────
class _UsersPage extends StatelessWidget {
  final List<UserDto> users;
  const _UsersPage({required this.users});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (ctx, i) {
        final u = users[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1A237E).withValues(alpha: 0.1),
              child: Text(u.firstName.isNotEmpty ? u.firstName[0] : '?', style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
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
                    if (u.isActive) {
                      ctx.read<AdminCubit>().lockUser(u.id);
                    } else {
                      ctx.read<AdminCubit>().unlockUser(u.id);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Bookings Page ─────────────────────────────────────────────────────────
class _BookingsPage extends StatelessWidget {
  final List<BookingDto> bookings;
  const _BookingsPage({required this.bookings});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (_, i) {
        final b = bookings[i];
        final statusColors = {
          BookingStatus.pending: Colors.orange,
          BookingStatus.confirmed: Colors.blue,
          BookingStatus.inProgress: Colors.purple,
          BookingStatus.completed: Colors.green,
          BookingStatus.cancelled: Colors.red,
          BookingStatus.noShow: Colors.grey,
        };
        final statusLabels = {
          BookingStatus.pending: 'Chờ',
          BookingStatus.confirmed: 'Xác nhận',
          BookingStatus.inProgress: 'Đang làm',
          BookingStatus.completed: 'Xong',
          BookingStatus.cancelled: 'Huỷ',
          BookingStatus.noShow: 'Vắng',
        };
        final color = statusColors[b.status] ?? Colors.grey;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
          child: Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${b.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${b.scheduledTime.day}/${b.scheduledTime.month}/${b.scheduledTime.year}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabels[b.status] ?? '', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }
}