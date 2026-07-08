import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/tier_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/customer_profile_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../auth/login_screen.dart';

// ─── Cubits ───────────────────────────────────────────────────────────────

abstract class ManagerBookingState {}
class ManagerBookingLoading extends ManagerBookingState {}
class ManagerBookingLoaded extends ManagerBookingState {
  final List<BookingDto> all;
  final List<BookingDto> pending;
  final List<BookingDto> inProgress;
  ManagerBookingLoaded(this.all)
      : pending = all.where((b) => b.status == BookingStatus.pending).toList(),
        inProgress = all.where((b) => b.status == BookingStatus.inProgress || b.status == BookingStatus.confirmed).toList();
}
class ManagerBookingError extends ManagerBookingState { final String msg; ManagerBookingError(this.msg); }

class ManagerBookingCubit extends Cubit<ManagerBookingState> {
  final _repo = BookingRepository();
  ManagerBookingCubit() : super(ManagerBookingLoading());

  Future<void> load() async {
    emit(ManagerBookingLoading());
    try {
      final list = await _repo.getAllBookings();
      list.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      emit(ManagerBookingLoaded(list));
    } catch (_) {
      emit(ManagerBookingError('Không tải được booking'));
    }
  }

  Future<void> confirm(String id) async {
    await _repo.updateBookingStatus(id, BookingStatus.confirmed.index);
    load();
  }

  Future<void> checkin(String id) async {
    await _repo.checkinBooking(id);
    load();
  }

  Future<void> complete(String id) async {
    await _repo.completeBooking(id);
    load();
  }
}

// ─── Manager User Cubit ───
abstract class ManagerUserState {}
class ManagerUserLoading extends ManagerUserState {}
class ManagerUserLoaded extends ManagerUserState {
  final List<UserDto> users;
  ManagerUserLoaded(this.users);
}
class ManagerUserError extends ManagerUserState { final String msg; ManagerUserError(this.msg); }

class ManagerUserCubit extends Cubit<ManagerUserState> {
  final _userRepo = UserRepository();
  ManagerUserCubit() : super(ManagerUserLoading());

  Future<void> load() async {
    emit(ManagerUserLoading());
    try {
      final users = await _userRepo.getAllUsers();
      emit(ManagerUserLoaded(users));
    } catch (_) {
      emit(ManagerUserError('Không tải được danh sách người dùng'));
    }
  }

  Future<void> lockUser(String id) async {
    await _userRepo.lockUser(id);
    load();
  }

  Future<void> unlockUser(String id) async {
    await _userRepo.unlockUser(id);
    load();
  }

  Future<void> createUser(CreateUserDto dto) async {
    try {
      await _userRepo.createUser(dto);
      load();
    } catch (_) {
      emit(ManagerUserError('Không thể tạo người dùng'));
    }
  }
}


// ─── Main Screen ──────────────────────────────────────────────────────────
class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});
  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ManagerBookingCubit()..load()),
        BlocProvider(create: (_) => ManagerUserCubit()..load()),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF004D40),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Manager Panel', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            Builder(builder: (ctx) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (_selectedIndex == 0) ctx.read<ManagerBookingCubit>().load();
                if (_selectedIndex == 1) ctx.read<ManagerUserCubit>().load();
              },
            )),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await context.read<AuthCubit>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            _ManagerBookingsPage(),
            _ManagerUsersPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF004D40).withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Bookings'),
            NavigationDestination(icon: Icon(Icons.people_rounded), label: 'Users'),
          ],
        ),
        floatingActionButton: _selectedIndex == 1
            ? FloatingActionButton.extended(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Thêm User'),
                onPressed: () => _showAddUserDialog(context),
              )
            : null,
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddUserDialog(
        onSubmit: (dto) => context.read<ManagerUserCubit>().createUser(dto),
      ),
    );
  }
}

// ─── Bookings Page ────────────────────────────────────────────────────────
class _ManagerBookingsPage extends StatefulWidget {
  const _ManagerBookingsPage();
  @override
  State<_ManagerBookingsPage> createState() => _ManagerBookingsPageState();
}

class _ManagerBookingsPageState extends State<_ManagerBookingsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF004D40),
            child: TabBar(
              onTap: (i) => setState(() => _tab = i),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'Tất cả'),
                Tab(text: 'Chờ xử lý'),
                Tab(text: 'Đang làm'),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<ManagerBookingCubit, ManagerBookingState>(
              builder: (ctx, state) {
                if (state is ManagerBookingLoading) return const Center(child: CircularProgressIndicator());
                if (state is ManagerBookingError) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(state.msg, style: const TextStyle(color: Colors.grey)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                        onPressed: () => ctx.read<ManagerBookingCubit>().load(),
                      ),
                    ],
                  ));
                }
                if (state is ManagerBookingLoaded) {
                  final lists = [state.all, state.pending, state.inProgress];
                  final bookings = lists[_tab];
                  if (bookings.isEmpty) return const Center(child: Text('Không có booking nào', style: TextStyle(color: Colors.grey, fontSize: 16)));
                  return RefreshIndicator(
                    onRefresh: () => ctx.read<ManagerBookingCubit>().load(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (_, i) => _ManagerBookingCard(booking: bookings[i]),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Users Page ───────────────────────────────────────────────────────────
class _ManagerUsersPage extends StatelessWidget {
  const _ManagerUsersPage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ManagerUserCubit, ManagerUserState>(
      builder: (ctx, state) {
        if (state is ManagerUserLoading) return const Center(child: CircularProgressIndicator());
        if (state is ManagerUserError) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(state.msg),
              ElevatedButton(onPressed: () => ctx.read<ManagerUserCubit>().load(), child: const Text('Thử lại')),
            ],
          ));
        }
        if (state is ManagerUserLoaded) {
          if (state.users.isEmpty) return const Center(child: Text('Không có người dùng nào', style: TextStyle(color: Colors.grey)));
          return RefreshIndicator(
            onRefresh: () => ctx.read<ManagerUserCubit>().load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.users.length,
              itemBuilder: (ctx, i) {
                final u = state.users[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                  child: ListTile(
                    onTap: () => _showUserDetailsDialog(context, u),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.1),
                      child: Text(u.firstName.isNotEmpty ? u.firstName[0] : '?', style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(u.email, style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: u.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(u.isActive ? 'Active' : 'Locked', style: TextStyle(color: u.isActive ? Colors.green : Colors.red, fontSize: 11)),
                        ),
                        IconButton(
                          icon: Icon(u.isActive ? Icons.lock_outline : Icons.lock_open, size: 20, color: u.isActive ? Colors.red : Colors.green),
                          onPressed: () {
                            if (u.isActive) ctx.read<ManagerUserCubit>().lockUser(u.id);
                            else ctx.read<ManagerUserCubit>().unlockUser(u.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  void _showUserDetailsDialog(BuildContext context, UserDto user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(user: user),
    );
  }
}

// ─── User Detail Bottom Sheet ─────────────────────────────────────────────

class _UserDetailSheet extends StatefulWidget {
  final UserDto user;
  const _UserDetailSheet({required this.user});
  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  final _repo = CustomerProfileRepository();
  Object? _ps;           // null=loading, false=notFound, CustomerProfileDto=found
  List<TierDto> _tiers = [];
  String? _selectedTierId;
  bool _creating = false;
  bool _savingTier = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _ps = null);
    try {
      // Fetch profile và tiers song song
      final results = await Future.wait([
        _repo.getProfileByCustomerId(widget.user.id),
        _repo.getAllTiers(),
      ]);
      final p = results[0] as CustomerProfileDto;
      final tiers = results[1] as List<TierDto>;

      // Enrich tier name nếu API không trả về
      CustomerProfileDto enriched = p;
      if ((p.currentTierName == null || p.currentTierName!.isEmpty) &&
          p.currentTierId.isNotEmpty) {
        final matched = tiers.where((t) => t.id == p.currentTierId).firstOrNull;
        if (matched != null) {
          enriched = CustomerProfileDto(
            id: p.id,
            currentTierId: p.currentTierId,
            currentTierName: matched.name,
            currentTier: matched,
            availablePoints: p.availablePoints,
            lifetimePoints: p.lifetimePoints,
            totalVisits: p.totalVisits,
            totalSpending: p.totalSpending,
            tierUpgradedAt: p.tierUpgradedAt,
            lastTierReviewDate: p.lastTierReviewDate,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
            updateBy: p.updateBy,
          );
        }
      }
      if (mounted) setState(() {
        _ps = enriched;
        _tiers = tiers;
        _selectedTierId = enriched.currentTierId.isNotEmpty ? enriched.currentTierId : null;
      });
    } catch (_) {
      if (mounted) setState(() => _ps = false);
    }
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      await _repo.createProfile(widget.user.id);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo profile thành công!'), backgroundColor: Colors.green));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo profile thất bại!'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return DraggableScrollableSheet(
      initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00695C)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(u.firstName.isNotEmpty ? u.firstName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 2),
                Text(u.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: u.isActive ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(u.isActive ? '● Đang hoạt động' : '● Bị khoá',
                    style: TextStyle(color: u.isActive ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ])),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context)),
            ]),
          ),
          // Body
          Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [
            _secTitle('Thông tin tài khoản'),
            const SizedBox(height: 8),
            _card([
              _row(Icons.badge_outlined, 'Username', u.userName),
              _row(Icons.phone_outlined, 'Số điện thoại', u.phoneNumber ?? 'Trống'),
              _row(Icons.cake_outlined, 'Ngày sinh',
                u.dateOfBirth != null
                  ? '${u.dateOfBirth!.day.toString().padLeft(2,'0')}/${u.dateOfBirth!.month.toString().padLeft(2,'0')}/${u.dateOfBirth!.year}'
                  : 'Trống'),
              _row(Icons.manage_accounts_outlined, 'Vai trò', u.role ?? 'N/A'),
              _row(Icons.fingerprint, 'ID', u.id, small: true),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Customer Profile',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600))),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            _buildProfile(),
          ])),
        ]),
      ),
    );
  }

  Widget _buildProfile() {
    if (_ps == null) {
      return const Padding(padding: EdgeInsets.all(24),
        child: Column(children: [
          CircularProgressIndicator(color: Color(0xFF004D40)),
          SizedBox(height: 12),
          Text('Đang tải Customer Profile...', style: TextStyle(color: Colors.grey)),
        ]));
    }
    if (_ps == false) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(children: [
          Icon(Icons.card_membership_outlined, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('Người dùng này chưa có Customer Profile',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _creating ? null : _create,
              icon: _creating
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.add_card_rounded),
              label: Text(_creating ? 'Đang tạo...' : 'Tạo Customer Profile'),
            )),
        ]));
    }
    final p = _ps as CustomerProfileDto;
    final tc = _tierColor(p.tierDisplayName);
    return Column(children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [tc.withValues(alpha: 0.8), tc]),
          borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(p.tierDisplayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _pStat('${p.availablePoints}', 'Điểm hiện có', Icons.stars_rounded),
            Container(width: 1, height: 36, color: Colors.white30),
            _pStat('${p.lifetimePoints}', 'Điểm trọn đời', Icons.workspace_premium_rounded),
            Container(width: 1, height: 36, color: Colors.white30),
            _pStat('${p.totalVisits}', 'Lượt rửa', Icons.local_car_wash_rounded),
          ]),
        ])),
      const SizedBox(height: 12),
      _card([
        _row(Icons.workspace_premium_rounded, 'Tier hiện tại', p.tierDisplayName),
        _row(Icons.payments_outlined, 'Tổng chi tiêu', '${(p.totalSpending / 1000).toStringAsFixed(0)}K đ'),
        if (p.tierUpgradedAt != null) _row(Icons.upgrade_rounded, 'Nâng tier lần cuối', _fmt(p.tierUpgradedAt!)),
        if (p.createdAt != null) _row(Icons.calendar_today_outlined, 'Ngày tạo profile', _fmt(p.createdAt!)),
      ]),
      // ── Thay đổi Tier thủ công ──
      if (_tiers.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF004D40).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF004D40).withValues(alpha: 0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.upgrade_rounded, size: 16, color: Color(0xFF004D40)),
              SizedBox(width: 6),
              Text('Thay đổi Tier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedTierId,
              decoration: InputDecoration(
                labelText: 'Chọn Tier mới',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              items: _tiers.map((t) => DropdownMenuItem(
                value: t.id,
                child: Row(children: [
                  Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('(≥${t.minPointsRequired} pts)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _selectedTierId = v),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (_savingTier || _selectedTierId == null || _selectedTierId == p.currentTierId)
                  ? null : () => _saveTier(p),
                icon: _savingTier
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
                label: Text(_savingTier ? 'Đang lưu...' : 'Lưu Tier'),
              )),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.green,
            side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => _pts(p, add: true),
          icon: const Icon(Icons.add_circle_outline, size: 18), label: const Text('Cộng điểm'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange), padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => _pts(p, add: false),
          icon: const Icon(Icons.remove_circle_outline, size: 18), label: const Text('Đổi điểm'))),
      ]),
    ]);
  }

  Future<void> _saveTier(CustomerProfileDto p) async {
    if (_selectedTierId == null) return;
    setState(() => _savingTier = true);
    try {
      await _repo.updateProfile(p.id, UpdateCustomerProfileDto(
        currentTierId: _selectedTierId,
        availablePoints: p.availablePoints,
        lifetimePoints: p.lifetimePoints,
        totalVisits: p.totalVisits,
        totalSpending: p.totalSpending,
      ));
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật Tier thành công!'), backgroundColor: Colors.green));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật Tier thất bại!'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _savingTier = false);
    }
  }

  void _pts(CustomerProfileDto p, {required bool add}) {
    final pc = TextEditingController(), nc = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(add ? 'Cộng điểm cho ${widget.user.fullName}' : 'Đổi điểm của ${widget.user.fullName}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!add) Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Text('Điểm hiện có: ${p.availablePoints}', style: const TextStyle(color: Colors.grey))),
        TextField(controller: pc, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Số điểm *',
            prefixIcon: const Icon(Icons.stars_rounded, color: Colors.amber),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        TextField(controller: nc, decoration: InputDecoration(labelText: 'Ghi chú (tuỳ chọn)',
          prefixIcon: const Icon(Icons.note_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: add ? Colors.green : Colors.orange, foregroundColor: Colors.white),
          onPressed: () async {
            final pts = int.tryParse(pc.text);
            if (pts == null || pts <= 0) return;
            Navigator.pop(context);
            try {
              if (add) await _repo.addPoints(p.id, pts, note: nc.text.isEmpty ? null : nc.text);
              else await _repo.redeemPoints(p.id, pts, note: nc.text.isEmpty ? null : nc.text);
              await _load();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(add ? 'Đã cộng $pts điểm!' : 'Đã đổi $pts điểm!'),
                backgroundColor: add ? Colors.green : Colors.orange));
            } catch (_) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Thao tác thất bại!'), backgroundColor: Colors.red));
            }
          },
          child: Text(add ? 'Cộng điểm' : 'Đổi điểm')),
      ],
    ));
  }

  Widget _secTitle(String t) => Row(children: [
    Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFF004D40), borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40))),
  ]);

  Widget _card(List<Widget> rows) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200)),
    child: Column(children: rows));

  Widget _row(IconData icon, String label, String value, {bool small = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF004D40).withValues(alpha: 0.7)),
      const SizedBox(width: 10),
      SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(value,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: small ? 11 : 13),
        overflow: TextOverflow.ellipsis)),
    ]));

  Widget _pStat(String value, String label, IconData icon) => Column(children: [
    Icon(icon, color: Colors.white70, size: 20),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]);

  Color _tierColor(String tier) {
    final t = tier.toLowerCase();
    if (t.contains('gold') || t.contains('vang')) return const Color(0xFFF59E0B);
    if (t.contains('silver') || t.contains('bac')) return const Color(0xFF64748B);
    if (t.contains('platinum')) return const Color(0xFF7C3AED);
    if (t.contains('diamond')) return const Color(0xFF06B6D4);
    return const Color(0xFF004D40);
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}


class _ManagerBookingCard extends StatelessWidget {
  final BookingDto booking;
  const _ManagerBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(booking.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Booking #${booking.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.$2.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusInfo.$1, style: TextStyle(color: statusInfo.$2, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${booking.scheduledTime.day}/${booking.scheduledTime.month}/${booking.scheduledTime.year}  ${booking.scheduledTime.hour.toString().padLeft(2, '0')}:${booking.scheduledTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (booking.status == BookingStatus.pending) ...[
                  Expanded(
                    child: _actionBtn(context, 'Xác nhận', Colors.blue,
                        () => context.read<ManagerBookingCubit>().confirm(booking.id)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (booking.status == BookingStatus.confirmed) ...[
                  Expanded(
                    child: _actionBtn(context, 'Check-in', Colors.purple,
                        () => context.read<ManagerBookingCubit>().checkin(booking.id)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (booking.status == BookingStatus.inProgress) ...[
                  Expanded(
                    child: _actionBtn(context, 'Hoàn thành ✓', Colors.green,
                        () => context.read<ManagerBookingCubit>().complete(booking.id)),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(BuildContext ctx, String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  (String, Color) _statusInfo(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending:    return ('Chờ xác nhận', Colors.orange);
      case BookingStatus.confirmed:  return ('Đã xác nhận', Colors.blue);
      case BookingStatus.inProgress: return ('Đang thực hiện', Colors.purple);
      case BookingStatus.completed:  return ('Hoàn thành', Colors.green);
      case BookingStatus.cancelled:  return ('Đã huỷ', Colors.red);
      case BookingStatus.noShow:     return ('Không đến', Colors.grey);
    }
  }
}

class _AddUserDialog extends StatefulWidget {
  final Function(CreateUserDto) onSubmit;
  const _AddUserDialog({required this.onSubmit});
  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _dob;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm người dùng'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _userName, decoration: const InputDecoration(labelText: 'Tên đăng nhập (Username)*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _password, decoration: const InputDecoration(labelText: 'Mật khẩu*'), obscureText: true, validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _firstName, decoration: const InputDecoration(labelText: 'Tên*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _lastName, decoration: const InputDecoration(labelText: 'Họ*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
              TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now());
                  if (date != null) setState(() => _dob = date);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày sinh', border: OutlineInputBorder()),
                  child: Text(_dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Chọn ngày sinh'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSubmit(CreateUserDto(
                userName: _userName.text,
                email: _email.text,
                password: _password.text,
                firstName: _firstName.text,
                lastName: _lastName.text,
                phoneNumber: _phone.text.isEmpty ? null : _phone.text,
                dateOfBirth: _dob,
              ));
              Navigator.pop(context);
            }
          },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

