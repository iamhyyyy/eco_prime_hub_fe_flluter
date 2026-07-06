import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/models/wash_service_model.dart';
import '../../../data/models/promotion_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/repositories/wash_service_repository.dart';
import '../../../data/repositories/promotion_repository.dart';
import 'package:dio/dio.dart';

// ─── Cubit ────────────────────────────────────────────────────────────────
abstract class BookingFormState {}
class BookingFormInitial extends BookingFormState {}
class BookingFormLoading extends BookingFormState {}
class BookingFormDataLoaded extends BookingFormState {
  final List<VehicleDto> vehicles;
  final List<WashServiceDto> services;
  final List<PromotionDto> promotions;
  BookingFormDataLoaded({required this.vehicles, required this.services, required this.promotions});
}
class BookingFormSuccess extends BookingFormState {}
class BookingFormError extends BookingFormState {
  final String message;
  BookingFormError(this.message);
}

class BookingFormCubit extends Cubit<BookingFormState> {
  final _bookingRepo = BookingRepository();
  final _vehicleRepo = VehicleRepository();
  final _serviceRepo = WashServiceRepository();
  final _promoRepo = PromotionRepository();

  BookingFormCubit() : super(BookingFormInitial());

  Future<void> loadData(String customerId) async {
    emit(BookingFormLoading());
    try {
      final results = await Future.wait([
        _vehicleRepo.getMyVehicles(customerId),
        _serviceRepo.getAllServices(),
        _promoRepo.getAllPromotions(),
      ]);
      emit(BookingFormDataLoaded(
        vehicles: results[0] as List<VehicleDto>,
        services: (results[1] as List<WashServiceDto>).where((s) => s.isActive).toList(),
        promotions: (results[2] as List<PromotionDto>).where((p) => p.isValid).toList(),
      ));
    } catch (_) {
      emit(BookingFormError('Không tải được dữ liệu'));
    }
  }

Future<void> submitBooking(CreateBookingDto dto) async {
    emit(BookingFormLoading());

    try {
      print("Request:");
      print(dto.toJson());

      await _bookingRepo.createBooking(dto);
      emit(BookingFormSuccess());
    } on DioException catch (e) {
      print("Status: ${e.response?.statusCode}");
      print("Response: ${e.response?.data}");

      final message =
          e.response?.data?['message'] ?? e.message ?? "Unknown error";

      emit(BookingFormError(message));
    } catch (e) {
      emit(BookingFormError(e.toString()));
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────
class BookingScreen extends StatelessWidget {
  final String customerId;
  const BookingScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BookingFormCubit()..loadData(customerId),
      child: _BookingForm(customerId: customerId),
    );
  }
}

class _BookingForm extends StatefulWidget {
  final String customerId;
  const _BookingForm({required this.customerId});

  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  VehicleDto? _selectedVehicle;
  WashServiceDto? _selectedService;
  PromotionDto? _selectedPromo;
  DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 1));
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Đặt lịch rửa xe', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocListener<BookingFormCubit, BookingFormState>(
        listener: (ctx, state) {
          if (state is BookingFormSuccess) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Đặt lịch thành công! 🎉'), backgroundColor: Colors.green));
            Navigator.pop(ctx, true);
          } else if (state is BookingFormError) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          } else if (state is BookingFormDataLoaded) {
            // Reset promo khi reload để tránh crash Dropdown
            setState(() => _selectedPromo = null);
          }
        },
        child: BlocBuilder<BookingFormCubit, BookingFormState>(
          builder: (ctx, state) {
            if (state is BookingFormLoading || state is BookingFormInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is BookingFormError && state is! BookingFormDataLoaded) {
              return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  ElevatedButton(onPressed: () => ctx.read<BookingFormCubit>().loadData(widget.customerId), child: const Text('Thử lại')),
                ],
              ));
            }
            if (state is BookingFormDataLoaded) {
              return _buildForm(ctx, state);
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext ctx, BookingFormDataLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🚗 Chọn xe'),
          const SizedBox(height: 8),
          state.vehicles.isEmpty
              ? const _EmptyCard(message: 'Bạn chưa có xe nào. Hãy thêm xe trước!')
              : _vehiclePicker(state.vehicles),

          const SizedBox(height: 20),
          _sectionTitle('🧹 Chọn dịch vụ'),
          const SizedBox(height: 8),
          _servicePicker(state.services),

          const SizedBox(height: 20),
          _sectionTitle('📅 Chọn thời gian'),
          const SizedBox(height: 8),
          _timePicker(ctx),

          const SizedBox(height: 20),
          _sectionTitle('💳 Phương thức thanh toán'),
          const SizedBox(height: 8),
          _paymentPicker(),

          if (state.promotions.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('🎁 Khuyến mãi (tuỳ chọn)'),
            const SizedBox(height: 8),
            _promoPicker(state.promotions),
          ],

          if (_selectedService != null) ...[
            const SizedBox(height: 20),
            _summaryCard(),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Xác nhận đặt lịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (_selectedVehicle == null || _selectedService == null)
                  ? null
                  : () {
                      ctx.read<BookingFormCubit>().submitBooking(CreateBookingDto(
                            customerId: widget.customerId,
                            vehicleId: _selectedVehicle!.id,
                            serviceId: _selectedService!.id,
                            promoId: _selectedPromo?.id,
                            scheduledTime: _scheduledTime,
                            paymentMethod: _paymentMethod,
                          ));
                    },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _vehiclePicker(List<VehicleDto> vehicles) {
    return Column(
      children: vehicles.map((v) {
        final isSelected = _selectedVehicle?.id == v.id;
        return GestureDetector(
          onTap: () => setState(() => _selectedVehicle = v),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0D47A1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? const Color(0xFF0D47A1) : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car, color: isSelected ? Colors.white : const Color(0xFF0D47A1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.licensePlate, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis),
                      Text('${v.brand} ${v.model} • ${v.vehicleTypeLabel}', style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle, color: Colors.white),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _servicePicker(List<WashServiceDto> services) {
    return Column(
      children: services.map((s) {
        final isSelected = _selectedService?.id == s.id;
        return GestureDetector(
          onTap: () => setState(() => _selectedService = s),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0D47A1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? const Color(0xFF0D47A1) : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.local_car_wash_rounded, color: isSelected ? Colors.white : const Color(0xFF0D47A1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
                      Text('${s.estimatedDurationMinutes} phút • +${s.pointsPerTransaction} điểm', style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
                    ],
                  ),
                ),
                Text('${_fmt(s.basePrice)}đ', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF0D47A1))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _timePicker(BuildContext ctx) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: ctx,
          initialDate: _scheduledTime,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (date == null) return;
        final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(_scheduledTime));
        if (time == null) return;
        setState(() => _scheduledTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF0D47A1)),
            const SizedBox(width: 12),
            Text(
              '${_scheduledTime.day}/${_scheduledTime.month}/${_scheduledTime.year}  ${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
            const Spacer(),
            const Icon(Icons.edit, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _paymentPicker() {
    final options = [
      (PaymentMethod.cash, 'Tiền mặt', Icons.money),
      (PaymentMethod.card, 'Thẻ ngân hàng', Icons.credit_card),
      (PaymentMethod.eWallet, 'Ví điện tử', Icons.account_balance_wallet),
    ];
    return Row(
      children: options.map((o) {
        final isSelected = _paymentMethod == o.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _paymentMethod = o.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0D47A1) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? const Color(0xFF0D47A1) : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(o.$3, color: isSelected ? Colors.white : Colors.grey, size: 20),
                  const SizedBox(height: 4),
                  Text(o.$2, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.w500), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _promoPicker(List<PromotionDto> promos) {
    return DropdownButtonFormField<PromotionDto>(
      value: _selectedPromo,
      hint: const Text('Không dùng khuyến mãi'),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Không dùng khuyến mãi')),
        ...promos.map((p) => DropdownMenuItem(value: p, child: Text('${p.promoName} — ${p.promoTypeLabel}', overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (p) => setState(() => _selectedPromo = p),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 Tóm tắt đơn hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (_selectedService != null)
            _summaryRow('Dịch vụ', _selectedService!.name),
          if (_selectedVehicle != null)
            _summaryRow('Xe', '${_selectedVehicle!.brand} ${_selectedVehicle!.model} (${_selectedVehicle!.licensePlate})'),
          _summaryRow('Thời gian', '${_scheduledTime.day}/${_scheduledTime.month}/${_scheduledTime.year}'),
          if (_selectedPromo != null)
            _summaryRow('Khuyến mãi', _selectedPromo!.promoName),
          const Divider(),
          _summaryRow(
            'Tổng tiền',
            '${_fmt(_selectedService?.basePrice ?? 0)}đ',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));

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

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.amber.shade800)),
    );
  }
}
