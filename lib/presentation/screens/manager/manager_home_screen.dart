import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../auth/login_screen.dart';

// ─── Cubit ────────────────────────────────────────────────────────────────
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

// ─── Screen ───────────────────────────────────────────────────────────────
class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});
  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ManagerBookingCubit()..load(),
      // DefaultTabController tự quản lý vsync, không cần Scaffold.of()
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF004D40),
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Manager Panel', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
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
            bottom: TabBar(
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
          body: BlocBuilder<ManagerBookingCubit, ManagerBookingState>(
            builder: (ctx, state) {
              if (state is ManagerBookingLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is ManagerBookingError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(state.msg, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                        onPressed: () => ctx.read<ManagerBookingCubit>().load(),
                      ),
                    ],
                  ),
                );
              }
              if (state is ManagerBookingLoaded) {
                final lists = [state.all, state.pending, state.inProgress];
                final bookings = lists[_tab];
                if (bookings.isEmpty) {
                  return const Center(
                    child: Text('Không có booking nào', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }
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
