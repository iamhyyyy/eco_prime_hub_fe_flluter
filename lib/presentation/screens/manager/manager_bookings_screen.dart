import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';

const _managerGreen = Color(0xFF004D40);

// ─── Cubit ────────────────────────────────────────────────────────────────

abstract class ManagerBookingState {}

class ManagerBookingLoading extends ManagerBookingState {}

class ManagerBookingLoaded extends ManagerBookingState {
  final List<BookingDto> bookings;
  final List<UserDto> users;
  final List<VehicleDto> vehicles;
  final String? message;

  ManagerBookingLoaded({
    required this.bookings,
    required this.users,
    required this.vehicles,
    this.message,
  });

  List<BookingDto> get pending => bookings.where((b) => b.status == BookingStatus.pending).toList();

  List<BookingDto> get inProgress => bookings
      .where((b) => b.status == BookingStatus.inProgress || b.status == BookingStatus.confirmed)
      .toList();

  List<BookingDto> get today => bookings.where((b) {
        final now = DateTime.now();
        return b.scheduledTime.year == now.year &&
            b.scheduledTime.month == now.month &&
            b.scheduledTime.day == now.day;
      }).toList();
}

class ManagerBookingError extends ManagerBookingState {
  final String msg;
  ManagerBookingError(this.msg);
}

class ManagerBookingCubit extends Cubit<ManagerBookingState> {
  final _bookingRepo = BookingRepository();
  final _userRepo = UserRepository();
  final _vehicleRepo = VehicleRepository();

  ManagerBookingCubit() : super(ManagerBookingLoading());

  Future<void> load({String? message}) async {
    emit(ManagerBookingLoading());
    try {
      final results = await Future.wait([
        _bookingRepo.getAllBookings(),
        _userRepo.getAllUsers(),
        _vehicleRepo.getAllVehicles(),
      ]);
      final bookings = results[0] as List<BookingDto>;
      bookings.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      emit(ManagerBookingLoaded(
        bookings: bookings,
        users: results[1] as List<UserDto>,
        vehicles: results[2] as List<VehicleDto>,
        message: message,
      ));
    } on DioException catch (e) {
      emit(ManagerBookingError(e.response?.data?['message'] ?? 'Không tải được booking'));
    } catch (_) {
      emit(ManagerBookingError('Không tải được booking'));
    }
  }

  Future<void> confirm(BookingDto booking) async {
    try {
      await _bookingRepo.confirmBooking(booking);
      await load(message: 'Đã xác nhận lịch hẹn');
    } on DioException catch (e) {
      emit(ManagerBookingError(e.response?.data?['message'] ?? 'Không xác nhận được'));
    }
  }

  Future<void> checkin(BookingDto booking) async {
    try {
      await _bookingRepo.checkinBooking(booking);
      await load(message: 'Đã check-in khách');
    } on DioException catch (e) {
      emit(ManagerBookingError(e.response?.data?['message'] ?? 'Không check-in được'));
    }
  }

  Future<void> complete(BookingDto booking) async {
    try {
      await _bookingRepo.completeBooking(booking);
      await load(message: 'Đã hoàn thành rửa xe');
    } on DioException catch (e) {
      emit(ManagerBookingError(e.response?.data?['message'] ?? 'Không hoàn thành được'));
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────

class ManagerBookingsPage extends StatefulWidget {
  const ManagerBookingsPage({super.key});

  @override
  State<ManagerBookingsPage> createState() => _ManagerBookingsPageState();
}

class _ManagerBookingsPageState extends State<ManagerBookingsPage> {
  int _tab = 0;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  UserDto? _findUser(ManagerBookingLoaded state, String id) {
    for (final u in state.users) {
      if (u.id == id) return u;
    }
    return null;
  }

  VehicleDto? _findVehicle(ManagerBookingLoaded state, String id) {
    for (final v in state.vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  List<BookingDto> _tabList(ManagerBookingLoaded state) {
    switch (_tab) {
      case 1:
        return state.today;
      case 2:
        return state.pending;
      case 3:
        return state.inProgress;
      default:
        return state.bookings;
    }
  }

  List<BookingDto> _filtered(ManagerBookingLoaded state) {
    final query = _searchCtrl.text.trim().toLowerCase();
    var list = _tabList(state);
    if (query.isEmpty) return list;

    return list.where((b) {
      final user = _findUser(state, b.customerId);
      final vehicle = _findVehicle(state, b.vehicleId);
      final haystack = [
        b.id,
        user?.fullName ?? '',
        user?.email ?? '',
        user?.phoneNumber ?? '',
        vehicle?.licensePlate ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ManagerBookingCubit, ManagerBookingState>(
      listener: (ctx, state) {
        if (state is ManagerBookingError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.msg), backgroundColor: Colors.red),
          );
        } else if (state is ManagerBookingLoaded && state.message != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.message!), backgroundColor: Colors.green),
          );
        }
      },
      builder: (ctx, state) {
        return Column(
          children: [
            _buildTabChips(),
            if (state is ManagerBookingLoaded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm biển số, SĐT, tên khách, mã booking...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            Expanded(child: _buildBody(ctx, state)),
          ],
        );
      },
    );
  }

  Widget _buildTabChips() {
    const labels = ['Tất cả', 'Hôm nay', 'Chờ xử lý', 'Đang làm'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _tab == i;
          return Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
            child: FilterChip(
              label: Text(labels[i]),
              selected: selected,
              onSelected: (_) => setState(() => _tab = i),
              selectedColor: _managerGreen.withValues(alpha: 0.15),
              checkmarkColor: _managerGreen,
              labelStyle: TextStyle(
                color: selected ? _managerGreen : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody(BuildContext ctx, ManagerBookingState state) {
    if (state is ManagerBookingLoading) {
      return const Center(child: CircularProgressIndicator(color: _managerGreen));
    }
    if (state is ManagerBookingError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.msg, style: const TextStyle(color: Colors.grey)),
            ElevatedButton(
              onPressed: () => ctx.read<ManagerBookingCubit>().load(),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (state is! ManagerBookingLoaded) return const SizedBox();

    final bookings = _filtered(state);
    if (bookings.isEmpty) {
      return const Center(child: Text('Không có booking nào', style: TextStyle(color: Colors.grey, fontSize: 16)));
    }

    return RefreshIndicator(
      color: _managerGreen,
      onRefresh: () => ctx.read<ManagerBookingCubit>().load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (_, i) {
          final booking = bookings[i];
          final user = _findUser(state, booking.customerId);
          final vehicle = _findVehicle(state, booking.vehicleId);
          return _ManagerBookingCard(
            booking: booking,
            customerName: user?.fullName ?? 'Khách #${booking.customerId.substring(0, 8)}',
            customerPhone: user?.phoneNumber ?? '',
            licensePlate: vehicle?.licensePlate ?? '—',
            onConfirm: () => ctx.read<ManagerBookingCubit>().confirm(booking),
            onCheckin: () => ctx.read<ManagerBookingCubit>().checkin(booking),
            onComplete: () => ctx.read<ManagerBookingCubit>().complete(booking),
          );
        },
      ),
    );
  }
}

class _ManagerBookingCard extends StatelessWidget {
  final BookingDto booking;
  final String customerName;
  final String customerPhone;
  final String licensePlate;
  final VoidCallback onConfirm;
  final VoidCallback onCheckin;
  final VoidCallback onComplete;

  const _ManagerBookingCard({
    required this.booking,
    required this.customerName,
    required this.customerPhone,
    required this.licensePlate,
    required this.onConfirm,
    required this.onCheckin,
    required this.onComplete,
  });

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
                    '#${booking.id.length >= 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}',
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
            _info(Icons.person_outline, customerName),
            if (customerPhone.isNotEmpty) _info(Icons.phone_outlined, customerPhone),
            _info(Icons.directions_car_outlined, licensePlate),
            _info(
              Icons.calendar_today_rounded,
              '${booking.scheduledTime.day}/${booking.scheduledTime.month}/${booking.scheduledTime.year}  ${booking.scheduledTime.hour.toString().padLeft(2, '0')}:${booking.scheduledTime.minute.toString().padLeft(2, '0')}',
            ),
            _info(Icons.payments_outlined, '${_fmt(booking.finalAmount)}đ • ${booking.paymentMethod.label}'),
            const SizedBox(height: 12),
            Row(
              children: [
                if (booking.status == BookingStatus.pending) ...[
                  Expanded(child: _actionBtn('Xác nhận', Colors.blue, onConfirm)),
                  const SizedBox(width: 8),
                ],
                if (booking.status == BookingStatus.confirmed) ...[
                  Expanded(child: _actionBtn('Check-in', Colors.purple, onCheckin)),
                  const SizedBox(width: 8),
                ],
                if (booking.status == BookingStatus.inProgress) ...[
                  Expanded(child: _actionBtn('Hoàn thành', Colors.green, onComplete)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
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
      case BookingStatus.pending:
        return ('Chờ xác nhận', Colors.orange);
      case BookingStatus.confirmed:
        return ('Đã xác nhận', Colors.blue);
      case BookingStatus.inProgress:
        return ('Đang thực hiện', Colors.purple);
      case BookingStatus.completed:
        return ('Hoàn thành', Colors.green);
      case BookingStatus.cancelled:
        return ('Đã huỷ', Colors.red);
      case BookingStatus.noShow:
        return ('Không đến', Colors.grey);
    }
  }

  String _fmt(double price) {
    final str = price.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if ((str.length - i) % 3 == 0 && i != 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
