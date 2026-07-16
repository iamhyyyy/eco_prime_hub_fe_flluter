import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../data/models/promotion_model.dart';
import 'manage_promotion_services_cubit.dart';

class ManagePromotionsScreen extends StatelessWidget {
  const ManagePromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ManagePromotionCubit()..load(),
      child: Builder(builder: (innerContext) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text("Quản lý Khuyến mãi", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
          ),
          body: BlocBuilder<ManagePromotionCubit, ManagePromotionState>(
            builder: (ctx, state) {
              if (state is MPromotionLoading) return const Center(child: CircularProgressIndicator());
              if (state is MPromotionLoaded) {
                if (state.promotions.isEmpty) return const Center(child: Text('Chưa có khuyến mãi nào'));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.promotions.length,
                  itemBuilder: (ctx, i) {
                    final p = state.promotions[i];
                    final opacity = p.isActive ? 1.0 : 0.5;

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
                          title: Text(p.promoName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                          subtitle: Text("Giảm: ${p.discountPercent.toInt()}% • Tier: ${p.minTierId ?? 'All'}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: p.isActive,
                                activeThumbColor: Colors.green,
                                onChanged: (_) => innerContext.read<ManagePromotionCubit>().toggleStatus(p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.show_chart, color: Colors.grey),
                                onPressed: () => _showPromotionDetailPopup(innerContext, p),
                              ),
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
            onPressed: () => _showAddDialog(innerContext),
            child: const Icon(Icons.add),
          ),
        );
      }),
    );
  }

  void _showPromotionDetailPopup(BuildContext ctx, PromotionDto p) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Chi tiết khuyến mãi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx)),
                ],
              ),
              const Divider(),
              Text(p.promoName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              const SizedBox(height: 10),
              Text("Giảm: ${p.discountPercent.toInt()}%"),
              Text("Tier ID: ${p.minTierId ?? 'Không yêu cầu'}"),
              Text("Mô tả: ${p.description}"),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
                  icon: const Icon(Icons.edit),
                  label: const Text('Chỉnh sửa'),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _showAddDialog(ctx, existing: p);
                  },
                ),
              )
            ],
          ),
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Thêm Khuyến mãi' : 'Chỉnh sửa Khuyến mãi', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên khuyến mãi *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: discCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% Giảm', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: tierCtrl, decoration: const InputDecoration(labelText: 'Tier ID', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
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
                );

                if (existing != null) {
                  await ctx.read<ManagePromotionCubit>().updatePromotion(dto);
                } else {
                  await ctx.read<ManagePromotionCubit>().addPromotion(dto);
                }

                Navigator.pop(sheetCtx);
                // Sau khi lưu xong thì Cubit trong hàm add/update Promotion đã có load(),
                // nhưng nếu muốn chắc chắn, bạn có thể gọi lại ở đây.
              },
              child: Text(existing == null ? 'Lưu' : 'Cập nhật'),
            )
          ],
        ),
      ),
    );
  }
}