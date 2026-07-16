import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/feedback_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/models/wash_service_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/repositories/wash_service_repository.dart';

const _primaryBlue = Color(0xFF0D47A1);

// ─── Cubit ────────────────────────────────────────────────────────────────

abstract class BookingHistoryState {}

class BookingHistoryLoading extends BookingHistoryState {}

class BookingHistoryLoaded extends BookingHistoryState {
  final List<BookingDto> bookings;
  final Map<String, FeedbackDto> feedbackByBookingId;
  final Map<String, VehicleDto> vehicleById;
  final Map<String, WashServiceDto> serviceById;
  final String? message;

  BookingHistoryLoaded({
    required this.bookings,
    required this.feedbackByBookingId,
    required this.vehicleById,
    required this.serviceById,
    this.message,
  });
}

class BookingHistoryError extends BookingHistoryState {
  final String msg;
  BookingHistoryError(this.msg);
}

class BookingHistoryCubit extends Cubit<BookingHistoryState> {
  final BookingRepository _bookingRepo = BookingRepository();
  final FeedbackRepository _feedbackRepo = FeedbackRepository();
  final VehicleRepository _vehicleRepo = VehicleRepository();
  final WashServiceRepository _serviceRepo = WashServiceRepository();

  BookingHistoryCubit() : super(BookingHistoryLoading());

  Future<void> load(String customerId, {String? message}) async {
    emit(BookingHistoryLoading());
    try {
      final results = await Future.wait([
        _bookingRepo.getBookingsByCustomer(customerId),
        _feedbackRepo.getMyFeedbacks(customerId),
        _vehicleRepo.getMyVehicles(customerId),
        _serviceRepo.getAllServices(),
      ]);
      final bookings = results[0] as List<BookingDto>;
      final feedbacks = results[1] as List<FeedbackDto>;
      final vehicles = results[2] as List<VehicleDto>;
      final services = results[3] as List<WashServiceDto>;
      bookings.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

      emit(BookingHistoryLoaded(
        bookings: bookings,
        feedbackByBookingId: {for (final f in feedbacks) f.bookingId: f},
        vehicleById: {for (final v in vehicles) v.id: v},
        serviceById: {for (final s in services) s.id: s},
        message: message,
      ));
    } on DioException catch (e) {
      emit(BookingHistoryError(e.response?.data?['message'] ?? 'Không tải được lịch sử'));
    } catch (_) {
      emit(BookingHistoryError('Không tải được lịch sử'));
    }
  }

  Future<void> cancel(String id, String reason, String customerId) async {
    final current = state;
    try {
      await _bookingRepo.cancelBooking(id, reason);
      await load(customerId, message: 'Đã huỷ lịch hẹn');
    } on DioException catch (e) {
      if (current is BookingHistoryLoaded) {
        emit(BookingHistoryLoaded(
          bookings: current.bookings,
          feedbackByBookingId: current.feedbackByBookingId,
          vehicleById: current.vehicleById,
          serviceById: current.serviceById,
          message: e.response?.data?['message'] ?? 'Không huỷ được lịch',
        ));
      } else {
        emit(BookingHistoryError(e.response?.data?['message'] ?? 'Không huỷ được lịch'));
      }
    } catch (_) {
      emit(BookingHistoryError('Không huỷ được lịch'));
    }
  }

  Future<void> submitFeedback({
    required String customerId,
    required String bookingId,
    required int rating,
    String? comment,
    FeedbackDto? existing,
  }) async {
    try {
      if (existing == null) {
        await _feedbackRepo.createFeedback(CreateFeedbackDto(
          bookingId: bookingId,
          customerId: customerId,
          rating: rating,
          comment: comment,
        ));
        await load(customerId, message: 'Cảm ơn bạn đã đánh giá!');
      } else {
        await _feedbackRepo.updateFeedback(
          existing.id,
          UpdateFeedbackDto(rating: rating, comment: comment),
        );
        await load(customerId, message: 'Đã cập nhật đánh giá');
      }
    } on DioException catch (e) {
      emit(BookingHistoryError(e.response?.data?['message'] ?? 'Không gửi được đánh giá'));
    } catch (_) {
      emit(BookingHistoryError('Không gửi được đánh giá'));
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────

enum _HistoryFilter { all, upcoming, completed, cancelled }

class BookingHistoryScreen extends StatelessWidget {
  final String customerId;
  const BookingHistoryScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return _HistoryView(customerId: customerId);
  }
}

class _HistoryView extends StatefulWidget {
  final String customerId;
  const _HistoryView({required this.customerId});

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  _HistoryFilter _filter = _HistoryFilter.all;

  List<BookingDto> _filtered(List<BookingDto> bookings) {
    switch (_filter) {
      case _HistoryFilter.upcoming:
        return bookings.where((b) =>
            b.status == BookingStatus.pending ||
            b.status == BookingStatus.confirmed).toList();
      case _HistoryFilter.completed:
        return bookings.where((b) => b.status == BookingStatus.completed).toList();
      case _HistoryFilter.cancelled:
        return bookings.where((b) =>
            b.status == BookingStatus.cancelled ||
            b.status == BookingStatus.noShow).toList();
      case _HistoryFilter.all:
        return bookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingHistoryCubit, BookingHistoryState>(
      listener: (ctx, state) {
        if (state is BookingHistoryError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.msg), backgroundColor: Colors.red),
          );
        } else if (state is BookingHistoryLoaded && state.message != null) {
          final isErrorMsg = state.message!.contains('Không');
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: isErrorMsg ? Colors.red : Colors.green,
            ),
          );
        }
      },
      builder: (ctx, state) {
        if (state is BookingHistoryLoading) {
          return const Center(child: CircularProgressIndicator(color: _primaryBlue));
        }
        if (state is BookingHistoryError && state is! BookingHistoryLoaded) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(state.msg, style: const TextStyle(color: Colors.grey)),
                ElevatedButton(
                  onPressed: () => ctx.read<BookingHistoryCubit>().load(widget.customerId),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        if (state is! BookingHistoryLoaded) return const SizedBox();

        final filtered = _filtered(state.bookings);

        return SafeArea(
          child: Column(
            children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              color: Colors.white,
              child: const Text(
                'Lịch sử đặt xe',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
              ),
            ),
            _buildFilterChips(),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty(state.bookings.isNotEmpty)
                  : RefreshIndicator(
                      color: _primaryBlue,
                      onRefresh: () => ctx.read<BookingHistoryCubit>().load(widget.customerId),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final booking = filtered[i];
                          final vehicle = state.vehicleById[booking.vehicleId];
                          final service = state.serviceById[booking.serviceId];
                          return _BookingCard(
                            booking: booking,
                            customerId: widget.customerId,
                            serviceName: service?.name ?? 'Dịch vụ #${booking.serviceId.substring(0, 8)}',
                            licensePlate: vehicle?.licensePlate ?? '—',
                            feedback: state.feedbackByBookingId[booking.id],
                            onReview: () => _showFeedbackSheet(
                              ctx,
                              booking: booking,
                              feedback: state.feedbackByBookingId[booking.id],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ));
      },
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _filterChip('Tất cả', _HistoryFilter.all),
          const SizedBox(width: 8),
          _filterChip('Sắp diễn ra', _HistoryFilter.upcoming),
          const SizedBox(width: 8),
          _filterChip('Hoàn thành', _HistoryFilter.completed),
          const SizedBox(width: 8),
          _filterChip('Đã huỷ', _HistoryFilter.cancelled),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _HistoryFilter value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: _primaryBlue.withValues(alpha: 0.15),
      checkmarkColor: _primaryBlue,
      labelStyle: TextStyle(
        color: selected ? _primaryBlue : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmpty(bool isFilteredEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            isFilteredEmpty ? 'Không có lịch trong bộ lọc này' : 'Chưa có lịch sử đặt xe',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showFeedbackSheet(
    BuildContext ctx, {
    required BookingDto booking,
    FeedbackDto? feedback,
  }) {
    showFeedbackFormSheet(
      ctx,
      customerId: widget.customerId,
      bookingId: booking.id,
      existing: feedback,
      onSubmit: (rating, comment) => ctx.read<BookingHistoryCubit>().submitFeedback(
            customerId: widget.customerId,
            bookingId: booking.id,
            rating: rating,
            comment: comment,
            existing: feedback,
          ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingDto booking;
  final String customerId;
  final String serviceName;
  final String licensePlate;
  final FeedbackDto? feedback;
  final VoidCallback? onReview;

  const _BookingCard({
    required this.booking,
    required this.customerId,
    required this.serviceName,
    required this.licensePlate,
    this.feedback,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(booking.status);
    final canCancel = booking.status == BookingStatus.pending ||
        booking.status == BookingStatus.confirmed;
    final canReview = booking.status == BookingStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
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
                    'Booking #${booking.id.length >= 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusInfo.$1,
                    style: TextStyle(color: statusInfo.$2, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.local_car_wash_rounded, serviceName),
            const SizedBox(height: 6),
            _infoRow(Icons.directions_car_outlined, licensePlate),
            const SizedBox(height: 6),
            _infoRow(Icons.calendar_today_rounded,
                '${booking.scheduledTime.day}/${booking.scheduledTime.month}/${booking.scheduledTime.year}  ${booking.scheduledTime.hour.toString().padLeft(2, '0')}:${booking.scheduledTime.minute.toString().padLeft(2, '0')}'),
            const SizedBox(height: 6),
            _infoRow(Icons.payments_rounded, '${_fmt(booking.finalAmount)}đ'),
            if (feedback != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  ...List.generate(5, (i) => Icon(
                        i < feedback!.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 20,
                      )),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feedback!.comment?.isNotEmpty == true ? feedback!.comment! : 'Đã đánh giá',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (canReview) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(feedback == null ? Icons.rate_review_outlined : Icons.edit_outlined, size: 18),
                  label: Text(feedback == null ? 'Đánh giá ngay' : 'Sửa đánh giá'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onReview,
                ),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                  label: const Text('Huỷ lịch', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Huỷ lịch'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Lý do huỷ (tuỳ chọn)', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Giữ lại')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<BookingHistoryCubit>().cancel(booking.id, controller.text, customerId);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Xác nhận huỷ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusInfo(BookingStatus status) {
    switch (status) {
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

/// Form đánh giá dùng chung cho Customer.
void showFeedbackFormSheet(
  BuildContext ctx, {
  required String customerId,
  required String bookingId,
  FeedbackDto? existing,
  required void Function(int rating, String? comment) onSubmit,
}) {
  int rating = existing?.rating ?? 5;
  final commentCtrl = TextEditingController(text: existing?.comment ?? '');
  final formKey = GlobalKey<FormState>();

  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (_, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rate_rounded, color: _primaryBlue, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      existing == null ? 'Đánh giá dịch vụ' : 'Sửa đánh giá',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Booking #${bookingId.length >= 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase()}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const Text('Bạn hài lòng mức nào?', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return IconButton(
                      onPressed: () => setSheetState(() => rating = star),
                      icon: Icon(
                        star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 40,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: commentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Nhận xét (tuỳ chọn)',
                    hintText: 'Chia sẻ trải nghiệm rửa xe của bạn...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    onSubmit(rating, commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim());
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(existing == null ? 'Gửi đánh giá' : 'Lưu thay đổi'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
