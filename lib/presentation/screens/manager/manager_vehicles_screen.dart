import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';

const _managerGreen = Color(0xFF004D40);

// ─── Cubit ────────────────────────────────────────────────────────────────

abstract class ManagerVehicleState {}

class ManagerVehicleLoading extends ManagerVehicleState {}

class ManagerVehicleLoaded extends ManagerVehicleState {
  final List<VehicleDto> vehicles;
  final List<UserDto> customers;
  final String? message;

  ManagerVehicleLoaded({
    required this.vehicles,
    required this.customers,
    this.message,
  });

  int get activeCount => vehicles.where((v) => v.isActive).length;
}

class ManagerVehicleError extends ManagerVehicleState {
  final String msg;
  ManagerVehicleError(this.msg);
}

class ManagerVehicleCubit extends Cubit<ManagerVehicleState> {
  final VehicleRepository _vehicleRepo = VehicleRepository();
  final UserRepository _userRepo = UserRepository();

  ManagerVehicleCubit() : super(ManagerVehicleLoading());

  Future<void> load({String? message}) async {
    emit(ManagerVehicleLoading());
    try {
      final results = await Future.wait([
        _vehicleRepo.getAllVehicles(),
        _userRepo.getAllUsers(),
      ]);
      final vehicles = results[0] as List<VehicleDto>;
      final customers = (results[1] as List<UserDto>)
          .where((u) => (u.role ?? '').toLowerCase().contains('customer'))
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));

      vehicles.sort((a, b) => a.licensePlate.compareTo(b.licensePlate));
      emit(ManagerVehicleLoaded(vehicles: vehicles, customers: customers, message: message));
    } on DioException catch (e) {
      emit(ManagerVehicleError(e.response?.data?['message'] ?? 'Không tải được danh sách xe'));
    } catch (_) {
      emit(ManagerVehicleError('Không tải được danh sách xe'));
    }
  }

  Future<void> addVehicle(CreateVehicleDto dto) async {
    try {
      await _vehicleRepo.createVehicle(dto);
      await load(message: 'Đã thêm xe ${dto.licensePlate}');
    } on DioException catch (e) {
      emit(ManagerVehicleError(e.response?.data?['message'] ?? 'Không thêm được xe'));
    } catch (_) {
      emit(ManagerVehicleError('Không thêm được xe'));
    }
  }

  Future<void> updateVehicle(String id, UpdateVehicleDto dto) async {
    try {
      await _vehicleRepo.updateVehicle(id, dto);
      await load(message: 'Đã cập nhật xe ${dto.licensePlate}');
    } on DioException catch (e) {
      emit(ManagerVehicleError(e.response?.data?['message'] ?? 'Không cập nhật được xe'));
    } catch (_) {
      emit(ManagerVehicleError('Không cập nhật được xe'));
    }
  }

  Future<void> setActive(VehicleDto vehicle, bool isActive) async {
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
      await _vehicleRepo.updateVehicle(vehicle.id, dto);
      final msg = isActive
          ? 'Đã kích hoạt lại xe ${vehicle.licensePlate}'
          : 'Đã ngưng hoạt động xe ${vehicle.licensePlate}';
      await load(message: msg);
    } on DioException catch (e) {
      emit(ManagerVehicleError(e.response?.data?['message'] ?? 'Không thay đổi được trạng thái xe'));
    } catch (_) {
      emit(ManagerVehicleError('Không thay đổi được trạng thái xe'));
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────

enum _VehicleFilter { all, active, inactive }

class ManagerVehiclesPage extends StatefulWidget {
  const ManagerVehiclesPage({super.key});

  @override
  State<ManagerVehiclesPage> createState() => _ManagerVehiclesPageState();
}

class _ManagerVehiclesPageState extends State<ManagerVehiclesPage> {
  final _searchCtrl = TextEditingController();
  _VehicleFilter _filter = _VehicleFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _customerLabel(UserDto? user) {
    if (user == null) return 'Khách hàng không xác định';
    return '${user.fullName} • ${user.email}';
  }

  List<VehicleDto> _applyFilters(ManagerVehicleLoaded state) {
    final query = _searchCtrl.text.trim().toLowerCase();
    var list = state.vehicles;

    switch (_filter) {
      case _VehicleFilter.active:
        list = list.where((v) => v.isActive).toList();
      case _VehicleFilter.inactive:
        list = list.where((v) => !v.isActive).toList();
      case _VehicleFilter.all:
        break;
    }

    if (query.isEmpty) return list;

    return list.where((v) {
      final customer = _findCustomer(state, v.customerId);
      final haystack = [
        v.licensePlate,
        v.brand,
        v.model,
        v.color,
        customer?.fullName ?? '',
        customer?.email ?? '',
        customer?.phoneNumber ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  UserDto? _findCustomer(ManagerVehicleLoaded state, String customerId) {
    for (final u in state.customers) {
      if (u.id == customerId) return u;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ManagerVehicleCubit, ManagerVehicleState>(
      listener: (ctx, state) {
        if (state is ManagerVehicleError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.msg), backgroundColor: Colors.red),
          );
        } else if (state is ManagerVehicleLoaded && state.message != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.message!), backgroundColor: Colors.green),
          );
        }
      },
      builder: (ctx, state) {
        if (state is ManagerVehicleLoading) {
          return const Center(child: CircularProgressIndicator(color: _managerGreen));
        }
        if (state is ManagerVehicleError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                Text(state.msg, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _managerGreen, foregroundColor: Colors.white),
                  onPressed: () => ctx.read<ManagerVehicleCubit>().load(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        if (state is! ManagerVehicleLoaded) return const SizedBox();

        final filtered = _applyFilters(state);

        return Column(
          children: [
            _buildHeader(state),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm biển số, hãng, tên hoặc email khách...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),
            _buildFilterChips(),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty(state.vehicles.isNotEmpty)
                  : RefreshIndicator(
                      color: _managerGreen,
                      onRefresh: () => ctx.read<ManagerVehicleCubit>().load(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final vehicle = filtered[i];
                          final customer = _findCustomer(state, vehicle.customerId);
                          return _ManagerVehicleCard(
                            vehicle: vehicle,
                            customerLabel: _customerLabel(customer),
                            onEdit: () => showManagerVehicleForm(ctx, state, vehicle: vehicle),
                            onToggleActive: () => _confirmToggleActive(ctx, vehicle),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(ManagerVehicleLoaded state) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _managerGreen.withValues(alpha: 0.25),
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
                const Text('Quản lý phương tiện', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${state.activeCount} hoạt động / ${state.vehicles.length} tổng',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.customers.length} khách hàng trong hệ thống',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
      selectedColor: _managerGreen.withValues(alpha: 0.15),
      checkmarkColor: _managerGreen,
      labelStyle: TextStyle(
        color: selected ? _managerGreen : Colors.grey.shade700,
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
            isFilteredEmpty ? 'Không có xe phù hợp bộ lọc' : 'Chưa có phương tiện nào',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
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
              ? 'Xe ${vehicle.licensePlate} sẽ không dùng được khi đặt lịch.'
              : 'Xe ${vehicle.licensePlate} sẽ hoạt động trở lại.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: deactivate ? Colors.orange : _managerGreen,
            ),
            onPressed: () {
              ctx.read<ManagerVehicleCubit>().setActive(vehicle, !deactivate);
              Navigator.pop(dialogCtx);
            },
            child: Text(deactivate ? 'Ngưng' : 'Kích hoạt', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ManagerVehicleCard extends StatelessWidget {
  final VehicleDto vehicle;
  final String customerLabel;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _ManagerVehicleCard({
    required this.vehicle,
    required this.customerLabel,
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
                    color: inactive ? Colors.grey.shade300 : _managerGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    vehicle.vehicleType == VehicleType.other ? Icons.directions_car : Icons.two_wheeler,
                    color: inactive ? Colors.grey : _managerGreen,
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
                              ),
                            ),
                          ),
                          _statusBadge(inactive),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vehicle.brand} ${vehicle.model} • ${vehicle.vehicleTypeLabel}${vehicle.color.isNotEmpty ? ' • ${vehicle.color}' : ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customerLabel,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                      foregroundColor: _managerGreen,
                      side: const BorderSide(color: _managerGreen),
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

void showManagerVehicleForm(BuildContext ctx, ManagerVehicleLoaded state, {VehicleDto? vehicle}) {
  final isEdit = vehicle != null;
  final formKey = GlobalKey<FormState>();
  final plateCtrl = TextEditingController(text: vehicle?.licensePlate ?? '');
  final brandCtrl = TextEditingController(text: vehicle?.brand ?? '');
  final modelCtrl = TextEditingController(text: vehicle?.model ?? '');
  final colorCtrl = TextEditingController(text: vehicle?.color ?? '');
  VehicleType selectedType = vehicle?.vehicleType ?? VehicleType.motorbike;
  String? selectedCustomerId = vehicle?.customerId ?? (state.customers.isNotEmpty ? state.customers.first.id : null);

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
                      color: _managerGreen,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit ? 'Chỉnh sửa xe' : 'Thêm xe cho khách',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (state.customers.isEmpty)
                  const Text(
                    'Chưa có khách hàng nào để gán xe.',
                    style: TextStyle(color: Colors.red),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedCustomerId,
                    decoration: const InputDecoration(
                      labelText: 'Khách hàng *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    items: state.customers
                        .map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.fullName} (${u.email})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: isEdit ? null : (v) => setSheetState(() => selectedCustomerId = v),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: plateCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Biển số xe *',
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
                    prefixIcon: Icon(Icons.business_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dòng xe',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Màu sắc',
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
                    backgroundColor: _managerGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: state.customers.isEmpty || selectedCustomerId == null
                      ? null
                      : () {
                          if (!formKey.currentState!.validate()) return;
                          final cubit = ctx.read<ManagerVehicleCubit>();
                          final customerId = selectedCustomerId!;
                          if (isEdit) {
                            cubit.updateVehicle(
                              vehicle.id,
                              UpdateVehicleDto(
                                customerId: customerId,
                                licensePlate: plateCtrl.text.trim().toUpperCase(),
                                vehicleType: selectedType,
                                brand: brandCtrl.text.trim(),
                                model: modelCtrl.text.trim(),
                                color: colorCtrl.text.trim(),
                                isActive: vehicle.isActive,
                              ),
                            );
                          } else {
                            cubit.addVehicle(
                              CreateVehicleDto(
                                customerId: customerId,
                                licensePlate: plateCtrl.text.trim().toUpperCase(),
                                vehicleType: selectedType,
                                brand: brandCtrl.text.trim(),
                                model: modelCtrl.text.trim(),
                                color: colorCtrl.text.trim(),
                              ),
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

/// Mở form thêm xe từ Manager Home (FAB).
void showManagerAddVehicleSheet(BuildContext context) {
  final state = context.read<ManagerVehicleCubit>().state;
  if (state is! ManagerVehicleLoaded) return;
  showManagerVehicleForm(context, state);
}
