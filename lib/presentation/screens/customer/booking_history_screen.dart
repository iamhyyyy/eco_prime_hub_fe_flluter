import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/repositories/booking_repository.dart';

// ─── Cubit ────────────────────────────────────────────────────────────────
abstract class BookingHistoryState {}
class BookingHistoryLoading extends BookingHistoryState {}
class BookingHistoryLoaded extends BookingHistoryState {
  final List<BookingDto> bookings;
  BookingHistoryLoaded(this.bookings);
}
class BookingHistoryError extends BookingHistoryState { final String msg; BookingHistoryError(this.msg); }

class BookingHistoryCubit extends Cubit<BookingHistoryState> {
  final BookingRepository _repo = BookingRepository();
  BookingHistoryCubit() : super(BookingHistoryLoading());

  Future<void> load(String customerId) async {
    emit(BookingHistoryLoading());
    try {
      final list = await _repo.getBookingsByCustomer(customerId);
      list.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      emit(BookingHistoryLoaded(list));
    } catch (_) {
      emit(BookingHistoryError('Không tải được lịch sử'));
    }
  }

  Future<void> cancel(String id, String reason, String customerId) async {
    try {
      await _repo.cancelBooking(id, reason);
      load(customerId);
    } catch (_) {}
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────
class BookingHistoryScreen extends StatelessWidget {
  final String customerId;
  const BookingHistoryScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BookingHistoryCubit()..load(customerId),
      child: _HistoryView(customerId: customerId),
    );
  }
}

class _HistoryView extends StatelessWidget {
  final String customerId;
  const _HistoryView({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingHistoryCubit, BookingHistoryState>(
      builder: (ctx, state) {
        if (state is BookingHistoryLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is BookingHistoryError) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text(state.msg, style: const TextStyle(color: Colors.grey)),
              ElevatedButton(onPressed: () => ctx.read<BookingHistoryCubit>().load(customerId), child: const Text('Thử lại')),
            ],
          ));
        }
        if (state is BookingHistoryLoaded) {
          if (state.bookings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có lịch sử đặt xe', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ctx.read<BookingHistoryCubit>().load(customerId),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.bookings.length,
              itemBuilder: (_, i) => _BookingCard(booking: state.bookings[i], customerId: customerId),
            ),
          );
        }
        return const SizedBox();
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingDto booking;
  final String customerId;
  const _BookingCard({required this.booking, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(booking.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: statusInfo.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusInfo.$1, style: TextStyle(color: statusInfo.$2, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.calendar_today_rounded, '${booking.scheduledTime.day}/${booking.scheduledTime.month}/${booking.scheduledTime.year}  ${booking.scheduledTime.hour.toString().padLeft(2, '0')}:${booking.scheduledTime.minute.toString().padLeft(2, '0')}'),
            const SizedBox(height: 6),
            _infoRow(Icons.payments_rounded, '${_fmt(booking.finalAmount)}đ'),
            if (booking.status == BookingStatus.pending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                  label: const Text('Huỷ lịch', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _showCancelDialog(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }

  void _showCancelDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Huỷ lịch'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Lý do huỷ (tuỳ chọn)', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Giữ lại')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<BookingHistoryCubit>().cancel(booking.id, controller.text, customerId);
              Navigator.pop(context);
            },
            child: const Text('Xác nhận huỷ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusInfo(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending: return ('Chờ xác nhận', Colors.orange);
      case BookingStatus.confirmed: return ('Đã xác nhận', Colors.blue);
      case BookingStatus.inProgress: return ('Đang thực hiện', Colors.purple);
      case BookingStatus.completed: return ('Hoàn thành', Colors.green);
      case BookingStatus.cancelled: return ('Đã huỷ', Colors.red);
      case BookingStatus.noShow: return ('Không đến', Colors.grey);
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
