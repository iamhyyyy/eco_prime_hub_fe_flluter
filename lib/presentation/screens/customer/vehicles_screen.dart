import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/repositories/vehicle_repository.dart';

// ─── Cubit ────────────────────────────────────────────────────────────────

abstract class VehicleState {}

class VehicleLoading extends VehicleState {}

class VehicleLoaded extends VehicleState {
  final List<VehicleDto> vehicles;
  final String? message;

  VehicleLoaded(this.vehicles, {this.message});

  int get activeCount => vehicles.where((v) => v.isActive).length;
}

class VehicleError extends VehicleState {
  final String msg;
  VehicleError(this.msg);
}

class VehicleCubit extends Cubit<VehicleState> {
  final VehicleRepository _repo = VehicleRepository();

  VehicleCubit() : super(VehicleLoading());

  Future<void> load(String customerId, {String? message}) async {
    emit(VehicleLoading());
    try {
      final list = await _repo.getMyVehicles(customerId);
      emit(VehicleLoaded(list, message: message));
    } on DioException catch (e) {
      emit(VehicleError(e.response?.data?['message'] ?? 'Không tải được danh sách xe'));
    } catch (_) {
      emit(VehicleError('Không tải được danh sách xe'));
    }
  }

  Future<void> addVehicle(CreateVehicleDto dto, String customerId) async {
    try {
      await _repo.createVehicle(dto);
      await load(customerId, message: 'Đã thêm xe ${dto.licensePlate}');
    } on DioException catch (e) {
      emit(VehicleError(e.response?.data?['message'] ?? 'Không thêm được xe'));
    } catch (_) {
      emit(VehicleError('Không thêm được xe'));
    }
  }

  Future<void> updateVehicle(String id, UpdateVehicleDto dto, String customerId) async {
    try {
      await _repo.updateVehicle(id, dto);
      await load(customerId, message: 'Đã cập nhật xe ${dto.licensePlate}');
    } on DioException catch (e) {
      emit(VehicleError(e.response?.data?['message'] ?? 'Không thêm được xe'));
    } catch (_) {
      emit(VehicleError('Không cập nhật được xe'));
    }
  }

  Future<void> setActive(VehicleDto vehicle, String customerId, bool isActive) async {
    final dto = UpdateVehicleDto(
      customerId: vehicle.customerId,
      licensePlate: vehicle.licensePlate,
      vehicleType: vehicle.vehicleType,
      brand: vehicle.brand,
      model: vehicle.model,
      color: vehicle.color,
      isActive: isActive,
    );
    try {
      await _repo.updateVehicle(vehicle.id, dto);
      final msg = isActive
          ? 'Đã kích hoạt lại xe ${vehicle.licensePlate}'
          : 'Đã ngưng hoạt động xe ${vehicle.licensePlate}';
      await load(customerId, message: msg);
    } on DioException catch (e) {
      emit(VehicleError(e.response?.data?['message'] ?? 'Không thay đổi được trạng thái xe'));
    } catch (_) {
      emit(VehicleError('Không thay đổi được trạng thái xe'));
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────

enum _VehicleFilter { all, active, inactive }

class VehiclesScreen extends StatelessWidget {
  final String customerId;
  const VehiclesScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VehicleCubit()..load(customerId),
      child: _VehiclesView(customerId: customerId),
    );
  }
}

class _VehiclesView extends StatefulWidget {
  final String customerId;
  const _VehiclesView({required this.customerId});

  @override
  State<_VehiclesView> createState() => _VehiclesViewState();
}

class _VehiclesViewState extends State<_VehiclesView> {
  _VehicleFilter _filter = _VehicleFilter.all;

  List<VehicleDto> _filtered(List<VehicleDto> vehicles) {
    switch (_filter) {
      case _VehicleFilter.active:
        return vehicles.where((v) => v.isActive).toList();
      case _VehicleFilter.inactive:
        return vehicles.where((v) => !v.isActive).toList();
      case _VehicleFilter.all:
        return vehicles;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Quản lý xe', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocConsumer<VehicleCubit, VehicleState>(
        listener: (ctx, state) {
          if (state is VehicleError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.msg), backgroundColor: Colors.red),
            );
          } else if (state is VehicleLoaded && state.message != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.message!), backgroundColor: Colors.green),
            );
          }
        },
        builder: (ctx, state) {
          if (state is VehicleLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is VehicleLoaded) {
            final filtered = _filtered(state.vehicles);

            return Column(
              children: [
                _buildHeader(state.activeCount, state.vehicles.length),
                _buildFilterChips(),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmpty(state.vehicles.isNotEmpty)
                      : RefreshIndicator(
                          onRefresh: () => ctx.read<VehicleCubit>().load(widget.customerId),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _VehicleCard(
                              vehicle: filtered[i],
                              onEdit: () => _showVehicleForm(ctx, vehicle: filtered[i]),
                              onToggleActive: () => _confirmToggleActive(ctx, filtered[i]),
                            ),
                          ),
                        ),
                ),
              ],
            );
          }
          if (state is VehicleError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(state.msg, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ctx.read<VehicleCubit>().load(widget.customerId),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm xe'),
        onPressed: () => _showVehicleForm(context),
      ),
    );
  }

  Widget _buildHeader(int activeCount, int totalCount) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF00838F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.directions_car_filled, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Xe của tôi', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '$activeCount đang hoạt động / $totalCount tổng',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip('Tất cả', _VehicleFilter.all),
          const SizedBox(width: 8),
          _filterChip('Hoạt động', _VehicleFilter.active),
          const SizedBox(width: 8),
          _filterChip('Ngưng', _VehicleFilter.inactive),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _VehicleFilter value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: const Color(0xFF0D47A1).withValues(alpha: 0.15),
      checkmarkColor: const Color(0xFF0D47A1),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0D47A1) : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmpty(bool isFilteredEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            isFilteredEmpty ? 'Không có xe trong bộ lọc này' : 'Chưa có xe nào',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          if (!isFilteredEmpty) ...[
            const SizedBox(height: 8),
            const Text('Thêm xe để bắt đầu đặt lịch rửa', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Thêm xe đầu tiên'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
              onPressed: () => _showVehicleForm(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showVehicleForm(BuildContext ctx, {VehicleDto? vehicle}) {
    final isEdit = vehicle != null;
    final formKey = GlobalKey<FormState>();
    final plateCtrl = TextEditingController(text: vehicle?.licensePlate ?? '');
    final brandCtrl = TextEditingController(text: vehicle?.brand ?? '');
    final modelCtrl = TextEditingController(text: vehicle?.model ?? '');
    final colorCtrl = TextEditingController(text: vehicle?.color ?? '');
    VehicleType selectedType = vehicle?.vehicleType ?? VehicleType.motorbike;

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
                      Icon(
                        isEdit ? Icons.edit_rounded : Icons.add_circle_outline,
                        color: const Color(0xFF0D47A1),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEdit ? 'Chỉnh sửa xe' : 'Thêm xe mới',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                    onChanged: (v) => setSheetState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final cubit = ctx.read<VehicleCubit>();
                      if (isEdit) {
                        cubit.updateVehicle(
                          vehicle.id,
                          UpdateVehicleDto(
                            customerId: widget.customerId,
                            licensePlate: plateCtrl.text.trim().toUpperCase(),
                            vehicleType: selectedType,
                            brand: brandCtrl.text.trim(),
                            model: modelCtrl.text.trim(),
                            color: colorCtrl.text.trim(),
                            isActive: vehicle.isActive,
                          ),
                          widget.customerId,
                        );
                      } else {
                        cubit.addVehicle(
                          CreateVehicleDto(
                            customerId: widget.customerId,
                            licensePlate: plateCtrl.text.trim().toUpperCase(),
                            vehicleType: selectedType,
                            brand: brandCtrl.text.trim(),
                            model: modelCtrl.text.trim(),
                            color: colorCtrl.text.trim(),
                          ),
                          widget.customerId,
                        );
                      }
                      Navigator.pop(sheetCtx);
                    },
                    child: Text(isEdit ? 'Lưu thay đổi' : 'Thêm xe'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmToggleActive(BuildContext ctx, VehicleDto vehicle) {
    final deactivate = vehicle.isActive;
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(deactivate ? 'Ngưng hoạt động xe?' : 'Kích hoạt lại xe?'),
        content: Text(
          deactivate
              ? 'Xe ${vehicle.licensePlate} sẽ không hiển thị khi đặt lịch. Bạn có thể kích hoạt lại sau.'
              : 'Xe ${vehicle.licensePlate} sẽ được dùng lại khi đặt lịch.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: deactivate ? Colors.orange : const Color(0xFF0D47A1),
            ),
            onPressed: () {
              ctx.read<VehicleCubit>().setActive(vehicle, widget.customerId, !deactivate);
              Navigator.pop(dialogCtx);
            },
            child: Text(deactivate ? 'Ngưng' : 'Kích hoạt', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final VehicleDto vehicle;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _VehicleCard({
    required this.vehicle,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = !vehicle.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: inactive ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: inactive ? Border.all(color: Colors.grey.shade300) : null,
        boxShadow: inactive
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: inactive
                        ? Colors.grey.shade300
                        : const Color(0xFF0D47A1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    vehicle.vehicleType == VehicleType.other
                        ? Icons.directions_car
                        : Icons.two_wheeler,
                    color: inactive ? Colors.grey : const Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicle.licensePlate,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: inactive ? Colors.grey.shade600 : Colors.black,
                                decoration: inactive ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          _statusBadge(inactive),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _vehicleSubtitle(vehicle),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Sửa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                      side: const BorderSide(color: Color(0xFF0D47A1)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggleActive,
                    icon: Icon(inactive ? Icons.check_circle_outline : Icons.block, size: 18),
                    label: Text(inactive ? 'Kích hoạt' : 'Ngưng'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: inactive ? Colors.green : Colors.orange,
                      side: BorderSide(color: inactive ? Colors.green : Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _vehicleSubtitle(VehicleDto v) {
    final parts = <String>[
      if (v.brand.isNotEmpty) v.brand,
      if (v.model.isNotEmpty) v.model,
      v.vehicleTypeLabel,
      if (v.color.isNotEmpty) v.color,
    ];
    return parts.isEmpty ? v.vehicleTypeLabel : parts.join(' • ');
  }

  Widget _statusBadge(bool inactive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: inactive ? Colors.grey.shade300 : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        inactive ? 'Ngưng' : 'Hoạt động',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: inactive ? Colors.grey.shade700 : const Color(0xFF2E7D32),
        ),
      ),
    );
  }
}
