import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/wash_service_model.dart';
import '../../../data/repositories/wash_service_repository.dart';
import 'booking_screen.dart';

// ─── Cubit ────────────────────────────────────────────────────────────────
abstract class ServiceState {}
class ServiceInitial extends ServiceState {}
class ServiceLoading extends ServiceState {}
class ServiceLoaded extends ServiceState {
  final List<WashServiceDto> services;
  ServiceLoaded(this.services);
}
class ServiceError extends ServiceState {
  final String message;
  ServiceError(this.message);
}

class ServiceCubit extends Cubit<ServiceState> {
  final WashServiceRepository _repo = WashServiceRepository();
  ServiceCubit() : super(ServiceInitial());

  Future<void> load() async {
    emit(ServiceLoading());
    try {
      final list = await _repo.getAllServices();
      emit(ServiceLoaded(list));
    } catch (_) {
      emit(ServiceError('Không tải được danh sách dịch vụ'));
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────
class ServicesScreen extends StatelessWidget {
  final String customerId;

  const ServicesScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ServiceCubit()..load(),
      child: _ServicesView(customerId: customerId),
    );
  }
}

class _ServicesView extends StatelessWidget {
  final String customerId;

  const _ServicesView({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServiceCubit, ServiceState>(
      builder: (ctx, state) {
        if (state is ServiceLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ServiceError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(state.message, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ctx.read<ServiceCubit>().load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        if (state is ServiceLoaded) {
          if (state.services.isEmpty) {
            return const Center(child: Text('Chưa có dịch vụ nào'));
          }
          final activeServices = state.services.where((s) => s.isActive).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                color: Colors.white,
                child: const Text(
                  'Dịch vụ rửa xe',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ctx.read<ServiceCubit>().load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: activeServices.length,
                    itemBuilder: (_, i) => _ServiceCard(
                      service: activeServices[i],
                      onBook: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingScreen(
                            customerId: customerId,
                            initialServiceId: activeServices[i].id,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return const SizedBox();
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final WashServiceDto service;
  final VoidCallback? onBook;

  const _ServiceCard({required this.service, this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_car_wash_rounded, color: Color(0xFF0D47A1), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (service.description != null) ...[
                    const SizedBox(height: 4),
                    Text(service.description!, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${service.estimatedDurationMinutes} phút', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFF57F17)),
                      const SizedBox(width: 4),
                      Text('+${service.pointsPerTransaction} điểm', style: const TextStyle(color: Color(0xFFF57F17), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_formatPrice(service.basePrice)}đ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1)),
                ),
                if (onBook != null && service.isActive) ...[
                  const SizedBox(height: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onBook,
                    child: const Text('Đặt ngay', style: TextStyle(fontSize: 12)),
                  ),
                ],
                if (!service.isActive)
                  const Chip(
                    label: Text('Tạm ngưng', style: TextStyle(fontSize: 10, color: Colors.red)),
                    backgroundColor: Color(0xFFFFEBEE),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    final str = price.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if ((str.length - i) % 3 == 0 && i != 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
