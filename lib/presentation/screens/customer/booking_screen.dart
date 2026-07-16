import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/promotion_model.dart';
import '../../../data/models/tier_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/models/wash_service_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/customer_profile_repository.dart';
import '../../../data/repositories/promotion_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/repositories/wash_service_repository.dart';


const _primaryBlue = Color(0xFF0D47A1);

// ─── Cubit ────────────────────────────────────────────────────────────────

abstract class BookingFormState {}

class BookingFormInitial extends BookingFormState {}

class BookingFormLoading extends BookingFormState {}

class BookingFormDataLoaded extends BookingFormState {
  final List<VehicleDto> vehicles;
  final List<WashServiceDto> services;
  final List<PromotionDto> promotions;
  final List<TierDto> tiers;
  final CustomerProfileDto? profile;

  BookingFormDataLoaded({
    required this.vehicles,
    required this.services,
    required this.promotions,
    required this.tiers,
    this.profile,
  });

  int get bookingWindowDays => profile?.currentTier?.bookingWindowDays ?? 7;

  double get pointMultiplier => profile?.currentTier?.pointMultiplier ?? 1.0;
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
  final _profileRepo = CustomerProfileRepository();

  BookingFormCubit() : super(BookingFormInitial());

  CustomerProfileDto? _enrichProfile(CustomerProfileDto? profile, List<TierDto> tiers) {
    if (profile == null) return null;
    if (profile.currentTier != null) return profile;

    final tier = tiers.where((t) => t.id == profile.currentTierId).firstOrNull;
    if (tier == null) return profile;

    return CustomerProfileDto(
      id: profile.id,
      currentTierId: profile.currentTierId,
      currentTierName: profile.currentTierName ?? tier.name,
      currentTier: tier,
      availablePoints: profile.availablePoints,
      lifetimePoints: profile.lifetimePoints,
      totalVisits: profile.totalVisits,
      totalSpending: profile.totalSpending,
      tierUpgradedAt: profile.tierUpgradedAt,
      lastTierReviewDate: profile.lastTierReviewDate,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
      updateBy: profile.updateBy,
    );
  }

  Future<void> loadData(String customerId) async {
    emit(BookingFormLoading());
    try {
      final results = await Future.wait([
        _vehicleRepo.getMyVehicles(customerId),
        _serviceRepo.getAllServices(),
        _promoRepo.getAllPromotions(),
        _profileRepo.getProfileByCustomerId(customerId),
        _profileRepo.getAllTiers(),
      ]);
      final tiers = results[4] as List<TierDto>;
      CustomerProfileDto? profile;
      try {
        profile = _enrichProfile(results[3] as CustomerProfileDto, tiers);
      } catch (_) {}

      emit(BookingFormDataLoaded(
        vehicles: (results[0] as List<VehicleDto>).where((v) => v.isActive).toList(),
        services: (results[1] as List<WashServiceDto>).where((s) => s.isActive).toList(),
        promotions: (results[2] as List<PromotionDto>).where((p) => p.isValid).toList(),
        profile: profile,
        tiers: tiers,
      ));
    } on DioException catch (e) {
      emit(BookingFormError(e.response?.data?['message'] ?? 'Không tải được dữ liệu'));
    } catch (_) {
      emit(BookingFormError('Không tải được dữ liệu'));
    }
  }

  Future<void> submitBooking(CreateBookingDto dto) async {
    emit(BookingFormLoading());
    try {
      await _bookingRepo.createBooking(dto);
      emit(BookingFormSuccess());
    } on DioException catch (e) {
      emit(BookingFormError(e.response?.data?['message'] ?? e.message ?? 'Đặt lịch thất bại'));
    } catch (e) {
      emit(BookingFormError(e.toString()));
    }
  }

  void restoreData(BookingFormDataLoaded data) => emit(data);
}

// ─── Screen ───────────────────────────────────────────────────────────────

class BookingScreen extends StatelessWidget {
  final String customerId;
  final String? initialServiceId;

  const BookingScreen({
    super.key,
    required this.customerId,
    this.initialServiceId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BookingFormCubit()..loadData(customerId),
      child: _BookingWizard(
        customerId: customerId,
        initialServiceId: initialServiceId,
      ),
    );
  }
}

class _BookingWizard extends StatefulWidget {
  final String customerId;
  final String? initialServiceId;

  const _BookingWizard({
    required this.customerId,
    this.initialServiceId,
  });

  @override
  State<_BookingWizard> createState() => _BookingWizardState();
}

class _BookingWizardState extends State<_BookingWizard> {
  int _step = 0;
  WashServiceDto? _selectedService;
  VehicleDto? _selectedVehicle;
  DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 1));
  PromotionDto? _selectedPromo;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  BookingFormDataLoaded? _cachedData;

  void _applyInitialService(BookingFormDataLoaded data) {
    final serviceId = widget.initialServiceId;
    if (serviceId == null || _selectedService != null) return;
    final match = data.services.where((s) => s.id == serviceId).firstOrNull;
    if (match != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedService = match);
      });
    }
  }

  double _finalAmount(BookingFormDataLoaded data) {
    final base = _selectedService?.basePrice ?? 0;
    final discount = _calcDiscount(base, _selectedPromo);
    return (base - discount).clamp(0, double.infinity).toDouble();
  }

  int _requiredPoints(BookingFormDataLoaded data) => _finalAmount(data).ceil();

  static const _stepTitles = [
    'Chọn dịch vụ',
    'Chọn xe',
    'Chọn thời gian',
    'Khuyến mãi',
    'Thanh toán',
    'Xác nhận',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Đặt lịch rửa xe', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocConsumer<BookingFormCubit, BookingFormState>(
        listener: (ctx, state) {
          if (state is BookingFormSuccess) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Đặt lịch thành công! 🎉'), backgroundColor: Colors.green),
            );
            Navigator.pop(ctx, true);
          } else if (state is BookingFormError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
            if (_cachedData != null) {
              ctx.read<BookingFormCubit>().restoreData(_cachedData!);
            }
          } else if (state is BookingFormDataLoaded) {
            _cachedData = state;
            _applyInitialService(state);
          }
        },
        builder: (ctx, state) {
          if ((state is BookingFormLoading || state is BookingFormInitial) && _cachedData == null) {
            return const Center(child: CircularProgressIndicator(color: _primaryBlue));
          }
          if (state is BookingFormError && _cachedData == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  ElevatedButton(
                    onPressed: () => ctx.read<BookingFormCubit>().loadData(widget.customerId),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final data = state is BookingFormDataLoaded ? state : _cachedData!;
          return Column(
            children: [
              _buildStepIndicator(),
              Expanded(child: _buildStepContent(ctx, data)),
              _buildNavButtons(ctx, data),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: _primaryBlue,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bước ${_step + 1}/6: ${_stepTitles[_step]}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(6, (i) {
              final done = i < _step;
              final active = i == _step;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 5 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done || active ? Colors.white : Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(BuildContext ctx, BookingFormDataLoaded data) {
    switch (_step) {
      case 0:
        return _serviceStep(data);
      case 1:
        return _vehicleStep(ctx, data);
      case 2:
        return _timeStep(data);
      case 3:
        return _promoStep(data);
      case 4:
        return _paymentStep(data);
      case 5:
        return _confirmStep(data);
      default:
        return const SizedBox();
    }
  }

  Widget _serviceStep(BookingFormDataLoaded data) {
    if (data.services.isEmpty) {
      return const Center(child: Text('Không có dịch vụ khả dụng', style: TextStyle(color: Colors.grey)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: data.services.map((s) {
        final selected = _selectedService?.id == s.id;
        final estPoints = (s.pointsPerTransaction * data.pointMultiplier).floor();
        return GestureDetector(
          onTap: () => setState(() => _selectedService = s),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? _primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? _primaryBlue : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.local_car_wash_rounded, color: selected ? Colors.white : _primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black)),
                      Text(
                        '${s.estimatedDurationMinutes} phút • +$estPoints điểm dự kiến',
                        style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_fmt(s.basePrice)}đ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : _primaryBlue),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showQuickAddVehicleDialog(BuildContext ctx) {
    final formKey = GlobalKey<FormState>();
    final plateCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    VehicleType selectedType = VehicleType.motorbike;
    bool saving = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Padding(
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
                      const Icon(Icons.add_circle_outline, color: _primaryBlue),
                      const SizedBox(width: 10),
                      const Text(
                        'Thêm xe nhanh',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: plateCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Biển số xe *',
                      hintText: 'VD: 51A-12345',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập biển số' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: brandCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Hãng xe',
                      hintText: 'VD: Honda, Yamaha',
                      prefixIcon: Icon(Icons.business_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dòng xe',
                      hintText: 'VD: Wave, Vision',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: colorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Màu sắc',
                      hintText: 'VD: Đỏ, Đen',
                      prefixIcon: Icon(Icons.palette_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<VehicleType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Loại xe *',
                      prefixIcon: Icon(Icons.two_wheeler_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: VehicleType.motorbike, child: Text('Xe máy')),
                      DropdownMenuItem(value: VehicleType.scooter, child: Text('Xe tay ga')),
                      DropdownMenuItem(value: VehicleType.other, child: Text('Khác')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: saving ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final newVehicle = await VehicleRepository().createVehicle(
                          CreateVehicleDto(
                            customerId: widget.customerId,
                            licensePlate: plateCtrl.text.trim().toUpperCase(),
                            vehicleType: selectedType,
                            brand: brandCtrl.text.trim(),
                            model: modelCtrl.text.trim(),
                            color: colorCtrl.text.trim(),
                          ),
                        );
                        if (ctx.mounted) {
                          ctx.read<BookingFormCubit>().loadData(widget.customerId);
                          setState(() {
                            _selectedVehicle = newVehicle;
                          });
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Đã thêm xe mới thành công!'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (dialogCtx.mounted) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text('Không thêm được xe: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        setDialogState(() => saving = false);
                      }
                    },
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Thêm và Chọn xe'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _vehicleStep(BuildContext ctx, BookingFormDataLoaded data) {
    if (data.vehicles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Bạn chưa có xe nào', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white),
                onPressed: () => _showQuickAddVehicleDialog(ctx),
                icon: const Icon(Icons.add),
                label: const Text('Thêm xe nhanh'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryBlue,
            side: const BorderSide(color: _primaryBlue),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _showQuickAddVehicleDialog(ctx),
          icon: const Icon(Icons.add),
          label: const Text('Thêm xe nhanh mới', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 14),
        ...data.vehicles.map((v) {
          final selected = _selectedVehicle?.id == v.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedVehicle = v),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? _primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? _primaryBlue : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    v.vehicleType == VehicleType.other ? Icons.directions_car : Icons.two_wheeler,
                    color: selected ? Colors.white : _primaryBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.licensePlate, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black)),
                        Text(
                          '${v.brand} ${v.model} • ${v.vehicleTypeLabel}',
                          style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (selected) const Icon(Icons.check_circle, color: Colors.white),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _timeStep(BookingFormDataLoaded data) {
    final maxDate = DateTime.now().add(Duration(days: data.bookingWindowDays));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(
              'Hạng ${data.profile?.tierDisplayName ?? 'Member'}: đặt trước tối đa ${data.bookingWindowDays} ngày',
              style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _scheduledTime.isBefore(DateTime.now()) ? DateTime.now() : _scheduledTime,
                firstDate: DateTime.now(),
                lastDate: maxDate,
              );
              if (date == null || !mounted) return;
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledTime));
              if (time == null || !mounted) return;
              final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              if (picked.isBefore(DateTime.now())) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Không được chọn thời gian trong quá khứ'), backgroundColor: Colors.red),
                );
                return;
              }
              setState(() => _scheduledTime = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: _primaryBlue),
                  const SizedBox(width: 12),
                  Text(
                    '${_scheduledTime.day}/${_scheduledTime.month}/${_scheduledTime.year}  ${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getPromotionIneligibilityReason(PromotionDto p, BookingFormDataLoaded data) {
    if (p.pointsCost > 0 && p.promoType != PromoType.pointBonus) {
      final availablePoints = data.profile?.availablePoints ?? 0;
      if (availablePoints < p.pointsCost) {
        return 'Không đủ điểm tích luỹ (Cần ${p.pointsCost} điểm)';
      }
    }
    if (p.minTierId != null && p.minTierId!.isNotEmpty) {
      final userTier = data.profile?.currentTier;
      final minTier = data.tiers.firstWhere(
        (t) => t.id == p.minTierId,
        orElse: () => TierDto(
          id: p.minTierId!,
          name: 'Yêu cầu',
          minPointsRequired: 0,
          bookingWindowDays: 7,
          priorityLevel: 0,
          pointMultiplier: 1.0,
          isActive: true,
        ),
      );
      final userPriority = userTier?.priorityLevel ?? 0;
      final reqPriority = minTier.priorityLevel;
      if (userPriority < reqPriority) {
        return 'Yêu cầu hạng ${minTier.name} trở lên';
      }
    }
    return null;
  }

  Widget _promoStep(BookingFormDataLoaded data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _promoNoneTile(),
        const SizedBox(height: 12),
        ...data.promotions.map((p) => _promoCard(p, data)),
      ],
    );
  }

  Widget _promoNoneTile() {
    final selected = _selectedPromo == null;
    return GestureDetector(
      onTap: () => setState(() => _selectedPromo = null),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _primaryBlue : Colors.grey.shade200),
          boxShadow: selected ? [BoxShadow(color: _primaryBlue.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Row(
          children: [
            Icon(Icons.block, color: selected ? Colors.white : Colors.grey),
            const SizedBox(width: 14),
            Text(
              'Không sử dụng khuyến mãi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promoCard(PromotionDto p, BookingFormDataLoaded data) {
    final reason = _getPromotionIneligibilityReason(p, data);
    final isEligible = reason == null;
    final selected = _selectedPromo?.id == p.id;

    final cardColor = selected
        ? _primaryBlue
        : (isEligible ? Colors.white : Colors.grey.shade50);
    final borderColor = selected
        ? _primaryBlue
        : (isEligible ? Colors.grey.shade200 : Colors.grey.shade300);
    final textColor = selected ? Colors.white : Colors.black87;
    final subtitleColor = selected ? Colors.white70 : Colors.grey.shade600;

    Color badgeBg;
    Color badgeText;
    String badgeLabel = '';
    
    switch (p.promoType) {
      case PromoType.discount:
        badgeBg = selected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE3F2FD);
        badgeText = selected ? Colors.white : const Color(0xFF1E88E5);
        badgeLabel = 'Giảm Giá';
        break;
      case PromoType.freeWash:
        badgeBg = selected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE8F5E9);
        badgeText = selected ? Colors.white : const Color(0xFF43A047);
        badgeLabel = 'Miễn Phí';
        break;
      case PromoType.addon:
        badgeBg = selected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFFFF3E0);
        badgeText = selected ? Colors.white : const Color(0xFFFB8C00);
        badgeLabel = 'Tặng Kèm';
        break;
      case PromoType.pointBonus:
        badgeBg = selected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF3E5F5);
        badgeText = selected ? Colors.white : const Color(0xFF8E24AA);
        badgeLabel = 'Tích Điểm';
        break;
    }

    return GestureDetector(
      onTap: isEligible ? () => setState(() => _selectedPromo = p) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1.0),
          boxShadow: selected
              ? [BoxShadow(color: _primaryBlue.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(
                left: -12,
                top: 40,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                ),
              ),
              Positioned(
                right: -12,
                top: 40,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Opacity(
                  opacity: isEligible ? 1.0 : 0.6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(color: badgeText, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            p.promoTypeLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: selected ? Colors.white : _primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        p.promoName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.description,
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                      const Divider(height: 20, thickness: 0.5),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: selected ? Colors.white70 : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Hạn: ${p.validTo.day}/${p.validTo.month}/${p.validTo.year}',
                            style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : Colors.grey),
                          ),
                          const Spacer(),
                          if (p.pointsCost > 0) ...[
                            Icon(
                              p.promoType == PromoType.pointBonus ? Icons.add_circle : Icons.stars_rounded,
                              size: 14,
                              color: selected ? Colors.amberAccent : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p.promoType == PromoType.pointBonus
                                  ? 'Tặng ${p.pointsCost} điểm'
                                  : 'Đổi bằng ${p.pointsCost} điểm',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: selected ? Colors.amberAccent : Colors.orange,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!isEligible) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              reason,
                              style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentStep(BookingFormDataLoaded data) {
    final base = _selectedService?.basePrice ?? 0;
    final discount = _calcDiscount(base, _selectedPromo);
    final finalAmount = _finalAmount(data);
    final availablePoints = data.profile?.availablePoints ?? 0;
    final requiredPoints = _requiredPoints(data);

    final options = [
      (PaymentMethod.cash, Icons.money, null),
      (PaymentMethod.transfer, Icons.account_balance, null),
      (
        PaymentMethod.points,
        Icons.stars_rounded,
        availablePoints < requiredPoints
            ? 'Cần $requiredPoints điểm (hiện có $availablePoints)'
            : 'Trừ $requiredPoints điểm khi hoàn tất',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _confirmRow('Giá gốc', '${_fmt(base)}đ'),
              if (discount > 0) _confirmRow('Giảm giá', '-${_fmt(discount)}đ'),
              _confirmRow('Thành tiền', '${_fmt(finalAmount)}đ', bold: true),
              if (data.profile != null)
                _confirmRow('Điểm khả dụng', '$availablePoints điểm'),
            ],
          ),
        ),
        ...options.map((o) {
          final method = o.$1;
          final disabled = method == PaymentMethod.points && availablePoints < requiredPoints;
          final selected = _paymentMethod == method;
          return GestureDetector(
            onTap: disabled ? null : () => setState(() => _paymentMethod = method),
            child: Opacity(
              opacity: disabled ? 0.55 : 1,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected ? _primaryBlue : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? _primaryBlue : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(o.$2, color: selected ? Colors.white : _primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : Colors.black,
                            ),
                          ),
                          if (o.$3 != null)
                            Text(
                              o.$3!,
                              style: TextStyle(
                                fontSize: 11,
                                color: selected ? Colors.white70 : (disabled ? Colors.red : Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _confirmStep(BookingFormDataLoaded data) {
    final base = _selectedService?.basePrice ?? 0;
    final discount = _calcDiscount(base, _selectedPromo);
    final finalAmount = _finalAmount(data);
    
    int estPoints = _selectedService == null
        ? 0
        : (_selectedService!.pointsPerTransaction * data.pointMultiplier).floor();
        
    if (_selectedPromo != null && _selectedPromo!.promoType == PromoType.pointBonus && _selectedPromo!.pointsCost > 0) {
      estPoints += _selectedPromo!.pointsCost;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xác nhận đặt lịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(height: 24),
            _confirmRow('Dịch vụ', _selectedService?.name ?? '—'),
            _confirmRow('Xe', _selectedVehicle != null ? '${_selectedVehicle!.licensePlate} (${_selectedVehicle!.brand} ${_selectedVehicle!.model})' : '—'),
            _confirmRow(
              'Thời gian',
              '${_scheduledTime.day}/${_scheduledTime.month}/${_scheduledTime.year} ${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
            ),
            _confirmRow('Khuyến mãi', _selectedPromo?.promoName ?? 'Không'),
            _confirmRow('Thanh toán', _paymentMethod.label),
            const Divider(height: 20),
            _confirmRow('Giá gốc', '${_fmt(base)}đ'),
            if (discount > 0) _confirmRow('Giảm giá', '-${_fmt(discount)}đ'),
            _confirmRow('Thành tiền', '${_fmt(finalAmount)}đ', bold: true),
            _confirmRow('Điểm dự kiến', '+$estPoints điểm'),
          ],
        ),
      ),
    );
  }

  Widget _confirmRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons(BuildContext ctx, BookingFormDataLoaded data) {
    final isLast = _step == 5;
    final canNext = _canProceed(data);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Quay lại'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: !canNext
                  ? null
                  : () {
                      if (isLast) {
                        ctx.read<BookingFormCubit>().submitBooking(CreateBookingDto(
                              customerId: widget.customerId,
                              vehicleId: _selectedVehicle!.id,
                              serviceId: _selectedService!.id,
                              promoId: _selectedPromo?.id,
                              scheduledTime: _scheduledTime,
                              paymentMethod: _paymentMethod,
                            ));
                      } else {
                        setState(() => _step++);
                      }
                    },
              child: Text(isLast ? 'Xác nhận đặt lịch' : 'Tiếp tục'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed(BookingFormDataLoaded data) {
    switch (_step) {
      case 0:
        return _selectedService != null;
      case 1:
        return _selectedVehicle != null;
      case 2:
        return _scheduledTime.isAfter(DateTime.now());
      case 3:
        return true;
      case 4:
        if (_paymentMethod != PaymentMethod.points) return true;
        return (data.profile?.availablePoints ?? 0) >= _requiredPoints(data);
      case 5:
        return _selectedService != null && _selectedVehicle != null;
      default:
        return false;
    }
  }

  double _calcDiscount(double base, PromotionDto? promo) {
    if (promo == null) return 0;
    switch (promo.promoType) {
      case PromoType.discount:
        return promo.discountAmount > 0
            ? promo.discountAmount
            : base * promo.discountPercent / 100;
      case PromoType.freeWash:
        return base;
      case PromoType.addon:
        return promo.discountAmount > 0
            ? promo.discountAmount
            : base * promo.discountPercent / 100;
      case PromoType.pointBonus:
        return 0;
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
