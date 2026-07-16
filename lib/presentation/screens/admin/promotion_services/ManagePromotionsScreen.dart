import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../data/models/promotion_model.dart';
import '../../../../data/models/tier_model.dart';
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
          floatingActionButton: BlocBuilder<ManagePromotionCubit, ManagePromotionState>(
            builder: (ctx, state) {
              final tiers = state is MPromotionLoaded ? state.tiers : <TierDto>[];
              return FloatingActionButton(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                onPressed: () => _showAddDialog(innerContext, tiers: tiers),
                child: const Icon(Icons.add),
              );
            },
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
                    final tiers = ctx.read<ManagePromotionCubit>().state is MPromotionLoaded 
                        ? (ctx.read<ManagePromotionCubit>().state as MPromotionLoaded).tiers 
                        : <TierDto>[];
                    _showAddDialog(ctx, existing: p, tiers: tiers);
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, {PromotionDto? existing, required List<TierDto> tiers}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _PromotionFormSheet(existing: existing, tiers: tiers, cubitContext: ctx),
    );
  }
}

class _PromotionFormSheet extends StatefulWidget {
  final PromotionDto? existing;
  final List<TierDto> tiers;
  final BuildContext cubitContext;

  const _PromotionFormSheet({this.existing, required this.tiers, required this.cubitContext});

  @override
  State<_PromotionFormSheet> createState() => _PromotionFormSheetState();
}

class _PromotionFormSheetState extends State<_PromotionFormSheet> {
  late TextEditingController nameCtrl;
  late TextEditingController descCtrl;
  late TextEditingController discPercentCtrl;
  late TextEditingController discAmountCtrl;
  late TextEditingController pointsCostCtrl;
  late TextEditingController maxUsesCtrl;

  PromoType selectedType = PromoType.discount;
  String? selectedTierId;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.existing?.promoName ?? '');
    descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    discPercentCtrl = TextEditingController(text: widget.existing?.discountPercent.toString() ?? '0');
    discAmountCtrl = TextEditingController(text: widget.existing?.discountAmount.toString() ?? '0');
    pointsCostCtrl = TextEditingController(text: widget.existing?.pointsCost.toString() ?? '0');
    maxUsesCtrl = TextEditingController(text: widget.existing?.maxUsesPerCustomer.toString() ?? '1');
    selectedType = widget.existing?.promoType ?? PromoType.discount;
    selectedTierId = widget.existing?.minTierId;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    discPercentCtrl.dispose();
    discAmountCtrl.dispose();
    pointsCostCtrl.dispose();
    maxUsesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Thêm Khuyến mãi' : 'Chỉnh sửa Khuyến mãi', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên khuyến mãi *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            
            DropdownButtonFormField<PromoType>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Loại khuyến mãi', border: OutlineInputBorder()),
              items: PromoType.values.map((t) {
                String label = '';
                switch (t) {
                  case PromoType.discount: label = 'Giảm giá'; break;
                  case PromoType.freeWash: label = 'Miễn phí rửa'; break;
                  case PromoType.addon: label = 'Tặng kèm'; break;
                  case PromoType.pointBonus: label = 'Tặng điểm'; break;
                }
                return DropdownMenuItem(value: t, child: Text(label));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => selectedType = v);
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: TextField(controller: discPercentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% Giảm', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: discAmountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tiền Giảm', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(child: TextField(controller: pointsCostCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Điểm trừ (nếu đổi)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: maxUsesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Lượt dùng/Khách', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String?>(
              value: selectedTierId,
              decoration: const InputDecoration(labelText: 'Hạng yêu cầu', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Tất cả hạng (Không yêu cầu)')),
                ...widget.tiers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
              ],
              onChanged: (v) => setState(() => selectedTierId = v),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                final dto = PromotionDto(
                  id: widget.existing?.id ?? '',
                  promoName: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  minTierId: selectedTierId,
                  promoType: selectedType,
                  pointsCost: int.tryParse(pointsCostCtrl.text) ?? 0,
                  discountAmount: double.tryParse(discAmountCtrl.text) ?? 0.0,
                  discountPercent: double.tryParse(discPercentCtrl.text) ?? 0.0,
                  validFrom: widget.existing?.validFrom ?? DateTime.now(),
                  validTo: widget.existing?.validTo ?? DateTime.now().add(const Duration(days: 30)),
                  maxUsesTotal: widget.existing?.maxUsesTotal,
                  maxUsesPerCustomer: int.tryParse(maxUsesCtrl.text) ?? 1,
                  isActive: widget.existing?.isActive ?? true,
                );

                if (widget.existing != null) {
                  await widget.cubitContext.read<ManagePromotionCubit>().updatePromotion(dto);
                } else {
                  await widget.cubitContext.read<ManagePromotionCubit>().addPromotion(dto);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: Text(widget.existing == null ? 'Lưu' : 'Cập nhật'),
            )
          ],
        ),
      ),
    );
  }
}