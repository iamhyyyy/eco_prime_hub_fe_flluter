import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/wash_service_model.dart';
import 'manage_wash_services_cubit.dart';

class ManageServicesScreen extends StatelessWidget {
  const ManageServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ManageWashServiceCubit()..load(),
      child: Builder(
          builder: (innerContext) {
            return Scaffold(
              backgroundColor: const Color(0xFFF5F7FA),
              appBar: AppBar(
                title: const Text("Quản lý dịch vụ", style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
              body: BlocBuilder<ManageWashServiceCubit, ManageServiceState>(
                builder: (ctx, state) {
                  if (state is MServiceLoading) return const Center(child: CircularProgressIndicator());
                  if (state is MServiceLoaded) {
                    if (state.services.isEmpty) return const Center(child: Text('Chưa có dịch vụ nào'));

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.services.length,
                      itemBuilder: (ctx, i) {
                        final s = state.services[i];
                        final opacity = s.isActive ? 1.0 : 0.5;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
                          ),
                          child: Opacity(
                            opacity: opacity,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Row(
                                children: [
                                  Expanded(
                                      child: Text(
                                          s.name.isEmpty ? "(Chưa có tên)" : s.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: s.isActive ? const Color(0xFF1A237E) : Colors.grey
                                          )
                                      )
                                  ),
                                  if (!s.isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Tạm ngưng', style: TextStyle(color: Colors.red, fontSize: 10)),
                                    )
                                ],
                              ),
                              subtitle: Text("${s.basePrice.toInt()}đ • ${s.estimatedDurationMinutes} phút\n+${s.pointsPerTransaction} điểm thưởng"),

                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: s.isActive,
                                    activeThumbColor: Colors.green,
                                    onChanged: (newValue) {
                                      innerContext.read<ManageWashServiceCubit>().toggleServiceStatus(s);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.show_chart, color: Colors.grey),
                                    onPressed: () {
                                      // Gọi hàm hiển thị Popup ở giữa màn hình
                                      _showServiceDetailPopup(innerContext, s);
                                    },
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
              floatingActionButton: FloatingActionButton(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
                onPressed: () => _showAddDialog(innerContext),
              ),
            );
          }
      ),
    );
  }

  // HÀM HIỂN THỊ POPUP Ở CHÍNH GIỮA MÀN HÌNH
  void _showServiceDetailPopup(BuildContext ctx, WashServiceDto s) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header với nút X
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Chi tiết dịch vụ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogCtx),
                  )
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              const SizedBox(height: 10),
              Text("Giá: ${s.basePrice.toInt()} VNĐ"),
              Text("Thời gian: ${s.estimatedDurationMinutes} phút"),
              Text("Điểm thưởng: +${s.pointsPerTransaction} điểm"),
              const SizedBox(height: 20),

              // Nút Chỉnh sửa
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Chỉnh sửa thông tin'),
                  onPressed: () {
                    Navigator.pop(dialogCtx); // Đóng popup chi tiết
                    _showAddDialog(ctx, existingService: s); // Mở form sửa
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
  void _showAddDialog(BuildContext ctx, {WashServiceDto? existingService}) {
    final nameCtrl = TextEditingController(text: existingService?.name ?? '');
    final priceCtrl = TextEditingController(text: existingService?.basePrice.toString() ?? '');
    final timeCtrl = TextEditingController(text: existingService?.estimatedDurationMinutes.toString() ?? '');
    final pointsCtrl = TextEditingController(text: existingService?.pointsPerTransaction.toString() ?? '');

    showModalBottomSheet(context: ctx, isScrollControlled: true, builder: (sheetCtx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existingService == null ? 'Thêm Dịch Vụ Mới' : 'Chỉnh sửa dịch vụ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên dịch vụ *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá (VNĐ)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: timeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Thời gian (phút)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: pointsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Điểm thưởng', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;

                  final dto = WashServiceDto(
                    id: existingService?.id ?? '', // GIỮ NGUYÊN ID ĐỂ CẬP NHẬT
                    name: nameCtrl.text.trim(),
                    basePrice: double.tryParse(priceCtrl.text) ?? 0,
                    estimatedDurationMinutes: int.tryParse(timeCtrl.text) ?? 0,
                    pointsPerTransaction: int.tryParse(pointsCtrl.text) ?? 0,
                    isActive: existingService?.isActive ?? true,
                  );

                  // LOGIC: Nếu có existingService thì gọi update, không thì gọi add
                  if (existingService != null) {
                    // Giả sử repository của bạn có hàm updateService(id, dto)
                    ctx.read<ManageWashServiceCubit>().updateService(dto);
                  } else {
                    ctx.read<ManageWashServiceCubit>().addService(dto);
                  }

                  Navigator.pop(sheetCtx);
                },
                child: Text(existingService == null ? 'Lưu Dịch Vụ' : 'Cập nhật')
            )
          ]
      ),
    ));
  }
}