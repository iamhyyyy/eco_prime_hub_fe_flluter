import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/wash_service_model.dart';
import '../../../data/repositories/wash_service_repository.dart';
import '../../../data/repositories/customer_profile_repository.dart';
import '../../../data/models/tier_model.dart';
import '../../blocs/auth/auth_cubit.dart';
import 'services_screen.dart';
import 'booking_screen.dart';
import 'booking_history_screen.dart';
import 'profile_screen.dart';
import 'vehicles_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;

  String get _userId {
    final state = context.read<AuthCubit>().state;
    if (state is AuthSuccess) return state.userId;
    return '';
  }

  List<Widget> get _pages => [
    _CustomerDashboard(userId: _userId),
    BookingHistoryScreen(customerId: _userId),
    ServicesScreen(),
    ProfileScreen(userId: _userId),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: const Color(0xFF0D47A1).withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Lịch sử'),
          NavigationDestination(icon: Icon(Icons.local_car_wash_rounded), label: 'Dịch vụ'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Hồ sơ'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Đặt lịch'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BookingScreen(customerId: _userId)),
              ).then((_) => setState(() {})),
            )
          : null,
    );
  }
}

// ─── Dashboard Home Page ───────────────────────────────────────────────────
class _CustomerDashboard extends StatefulWidget {
  final String userId;
  const _CustomerDashboard({required this.userId});

  @override
  State<_CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<_CustomerDashboard> {
  List<WashServiceDto> _services = [];
  CustomerProfileDto? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final services = await WashServiceRepository().getAllServices();
      CustomerProfileDto? profile;
      try {
        profile = await CustomerProfileRepository().getProfileByCustomerId(widget.userId);
      } catch (_) {}
      if (mounted) setState(() { _services = services.where((s) => s.isActive).take(4).toList(); _profile = profile; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async { setState(() => _loading = true); await _loadData(); },
              child: CustomScrollView(
                slivers: [
                  // App bar gradient
                  SliverAppBar(
                    expandedHeight: 180,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0D47A1), Color(0xFF00838F)],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Xin chào! 👋', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 4),
                                const Text('Eco Prime Hub', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                if (_profile != null)
                                  Row(
                                    children: [
                                      _pointBadge('${_profile!.availablePoints} điểm', Icons.stars_rounded, Colors.amber),
                                      const SizedBox(width: 10),
                                      _pointBadge(_profile!.currentTier?.name ?? 'Member', Icons.workspace_premium, Colors.white70),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.directions_car_outlined),
                        tooltip: 'Xe của tôi',
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VehiclesScreen(customerId: widget.userId))),
                      ),
                    ],
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick actions
                          const Text('Thao tác nhanh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _quickAction(Icons.add_circle_rounded, 'Đặt lịch', const Color(0xFF0D47A1), () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(customerId: widget.userId)))),
                              const SizedBox(width: 12),
                              _quickAction(Icons.directions_car_rounded, 'Thêm xe', const Color(0xFF00838F), () => Navigator.push(context, MaterialPageRoute(builder: (_) => VehiclesScreen(customerId: widget.userId)))),
                              const SizedBox(width: 12),
                              _quickAction(Icons.history_rounded, 'Lịch sử', const Color(0xFF6A1B9A), () {}),
                            ],
                          ),

                          // Services
                          const SizedBox(height: 24),
                          const Text('Dịch vụ nổi bật', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          if (_services.isEmpty)
                            const Center(child: Text('Không có dịch vụ', style: TextStyle(color: Colors.grey)))
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _services.length,
                              itemBuilder: (_, i) => _MiniServiceCard(service: _services[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _pointBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniServiceCard extends StatelessWidget {
  final WashServiceDto service;
  const _MiniServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_car_wash_rounded, color: Color(0xFF0D47A1), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text('${service.estimatedDurationMinutes} phút • +${service.pointsPerTransaction} điểm', style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_fmt(service.basePrice)}đ',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
          ),
        ],
      ),
    );
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
