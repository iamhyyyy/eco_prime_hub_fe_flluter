import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/promotion_model.dart';
import '../../../../data/models/booking_model.dart';
import 'manage_promotion_services_cubit.dart';
// import 'package:eco_prime_hub/data/services/user_session.dart';

class ManagePromotionsScreen extends StatelessWidget {
  const ManagePromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ManagePromotionCubit()..load(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text("Quản lý Khuyến mãi", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
        ),
        // Sử dụng Builder để có context chứa BlocProvider
        body: BlocBuilder<ManagePromotionCubit, ManagePromotionState>(
          builder: (ctx, state) {
            if (state is MPromotionLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is MPromotionLoaded) {
              // Bọc trong Column và Expanded để sửa lỗi Width is zero
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.promotions.length,
                      itemBuilder: (ctx, i) {
                        final p = state.promotions[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(p.promoName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Giảm: ${p.discountPercent.toStringAsFixed(0)}% - Hạn: ${p.validTo.day}/${p.validTo.month}/${p.validTo.year}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: p.isActive,
                                  onChanged: (_) => ctx.read<ManagePromotionCubit>().toggleStatus(p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showAddDialog(ctx, existing: p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => ctx.read<ManagePromotionCubit>().deletePromotion(p.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }
            return const Center(child: Text("Không có dữ liệu"));
          },
        ),
        floatingActionButton: Builder(builder: (newCtx) {
          return FloatingActionButton(
            backgroundColor: const Color(0xFF1A237E),
            onPressed: () => _showAddDialog(newCtx),
            child: const Icon(Icons.add, color: Colors.white),
          );
        }),
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, {PromotionDto? existing}) {
    final nameCtrl = TextEditingController(text: existing?.promoName ?? '');
    final discCtrl = TextEditingController(text: existing?.discountPercent.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final tierCtrl = TextEditingController(text: existing?.minTierId ?? '');

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(existing == null ? 'Thêm Khuyến mãi' : 'Chỉnh sửa Khuyến mãi',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên khuyến mãi')),
              TextField(controller: discCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% Giảm')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
              TextField(controller: tierCtrl, decoration: const InputDecoration(labelText: 'Tier ID (UUID)')),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
                onPressed: () async {
                  // // Hiển thị loading nhẹ hoặc feedback cho user
                  // final String? userId = await UserSession.getUserId();

                  // if (userId == null) {
                  //   ScaffoldMessenger.of(ctx).showSnackBar(
                  //     const SnackBar(content: Text("Lỗi: Không tìm thấy phiên đăng nhập!")),
                  //   );
                  //   return;
                  // }

                  final dto = PromotionDto(
                    id: existing?.id ?? '',
                    promoName: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    minTierId: tierCtrl.text.trim().isEmpty ? null : tierCtrl.text.trim(),
                    promoType: existing?.promoType ?? PromoType.percentage,
                    pointsCost: existing?.pointsCost ?? 0,
                    discountAmount: existing?.discountAmount ?? 0,
                    discountPercent: double.tryParse(discCtrl.text) ?? 0.0,
                    validFrom: existing?.validFrom ?? DateTime.now(),
                    validTo: existing?.validTo ?? DateTime.now().add(const Duration(days: 30)),
                    maxUsesTotal: existing?.maxUsesTotal,
                    maxUsesPerCustomer: existing?.maxUsesPerCustomer ?? 1,
                    isActive: existing?.isActive ?? true,
                    // createdBy: userId,
                  );

                  if (existing == null) {
                    await ctx.read<ManagePromotionCubit>().addPromotion(dto);
                  } else {
                    await ctx.read<ManagePromotionCubit>().updatePromotion(dto);
                  }

                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                },
                child: Text(existing == null ? 'Lưu' : 'Cập nhật'),
              )
            ],
          ),
        ),
      ),
    );
  }
}