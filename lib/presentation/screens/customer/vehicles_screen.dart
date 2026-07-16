import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/models/booking_model.dart';

// ─── Cubit ────────────────────────────────────────────────────────────────
abstract class VehicleState {}
class VehicleLoading extends VehicleState {}
class VehicleLoaded extends VehicleState { final List<VehicleDto> vehicles; VehicleLoaded(this.vehicles); }
class VehicleError extends VehicleState { final String msg; VehicleError(this.msg); }

class VehicleCubit extends Cubit<VehicleState> {
  final VehicleRepository _repo = VehicleRepository();
  VehicleCubit() : super(VehicleLoading());

  Future<void> load(String customerId) async {
    emit(VehicleLoading());
    try {
      final list = await _repo.getMyVehicles(customerId);
      emit(VehicleLoaded(list));
    } catch (_) {
      emit(VehicleError('Không tải được danh sách xe'));
    }
  }

  Future<void> addVehicle(CreateVehicleDto dto, String customerId) async {
    try {
      await _repo.createVehicle(dto);
      load(customerId);
    } catch (e) {
      emit(VehicleError('Không thêm được xe: ${e.toString()}'));
    }
  }

  Future<void> deleteVehicle(String id, String customerId) async {
    try {
      await _repo.deleteVehicle(id);
      load(customerId);
    } catch (_) {}
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────
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

class _VehiclesView extends StatelessWidget {
  final String customerId;
  const _VehiclesView({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Xe của tôi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddVehicle(context),
          ),
        ],
      ),
      body: BlocConsumer<VehicleCubit, VehicleState>(
        listener: (ctx, state) {
          if (state is VehicleError) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(state.msg), backgroundColor: Colors.red));
          }
        },
        builder: (ctx, state) {
          if (state is VehicleLoading) return const Center(child: CircularProgressIndicator());
          if (state is VehicleLoaded) {
            if (state.vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Chưa có xe nào', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm xe'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
                      onPressed: () => _showAddVehicle(ctx),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => ctx.read<VehicleCubit>().load(customerId),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.vehicles.length,
                itemBuilder: (_, i) => _VehicleCard(vehicle: state.vehicles[i], customerId: customerId),
              ),
            );
          }
          return const SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showAddVehicle(context),
      ),
    );
  }

  void _showAddVehicle(BuildContext ctx) {
    final plateCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    VehicleType selectedType = VehicleType.sedan;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Thêm xe mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Biển số xe *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Hãng xe (VD: Toyota)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Mẫu xe (VD: Camry)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: 'Màu sắc', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<VehicleType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Loại xe', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: VehicleType.sedan, child: Text('Sedan')),
                    DropdownMenuItem(value: VehicleType.suv, child: Text('SUV')),
                    DropdownMenuItem(value: VehicleType.motorcycle, child: Text('Xe máy')),
                  ],
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                  onPressed: () {
                    if (plateCtrl.text.isEmpty) return;
                    ctx.read<VehicleCubit>().addVehicle(
                      CreateVehicleDto(
                        customerId: customerId,
                        licensePlate: plateCtrl.text.trim().toUpperCase(),
                        vehicleType: selectedType,
                        brand: brandCtrl.text.trim(),
                        model: modelCtrl.text.trim(),
                        color: colorCtrl.text.trim(),
                      ),
                      customerId,
                    );
                    Navigator.pop(sheetCtx);
                  },
                  child: const Text('Thêm xe'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final VehicleDto vehicle;
  final String customerId;
  const _VehicleCard({required this.vehicle, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: const Color(0xFF0D47A1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(
            vehicle.vehicleType == VehicleType.motorcycle ? Icons.motorcycle : Icons.directions_car,
            color: const Color(0xFF0D47A1),
          ),
        ),
        title: Text(vehicle.licensePlate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text('${vehicle.brand} ${vehicle.model} • ${vehicle.color}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Xoá xe?'),
              content: Text('Bạn có chắc muốn xoá xe ${vehicle.licensePlate}?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    context.read<VehicleCubit>().deleteVehicle(vehicle.id, customerId);
                    Navigator.pop(context);
                  },
                  child: const Text('Xoá', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
