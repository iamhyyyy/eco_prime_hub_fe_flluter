import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/tier_model.dart';
import '../../../data/repositories/customer_profile_repository.dart';

// ─── States ───────────────────────────────────────────────────────────────

abstract class CpState {}
class CpLoading extends CpState {}
class CpLoaded extends CpState {
  final List<CustomerProfileDto> profiles;
  final List<TierDto> tiers;
  final String query;
  CpLoaded(this.profiles, this.tiers, {this.query = ''});
  List<CustomerProfileDto> get filtered {
    if (query.isEmpty) return profiles;
    final q = query.toLowerCase();
    return profiles.where((p) =>
      p.id.toLowerCase().contains(q) ||
      (p.currentTierName ?? '').toLowerCase().contains(q)
    ).toList();
  }
}
class CpError extends CpState { final String msg; CpError(this.msg); }

// ─── Cubit ────────────────────────────────────────────────────────────────

class CustomerProfileCubit extends Cubit<CpState> {
  final _repo = CustomerProfileRepository();
  List<CustomerProfileDto> _profiles = [];
  List<TierDto> _tiers = [];
  String _query = '';

  CustomerProfileCubit() : super(CpLoading());

  Future<void> load() async {
    emit(CpLoading());
    try {
      final results = await Future.wait([
        _repo.getAllProfiles(),
        _repo.getAllTiers(),
      ]);
      _profiles = results[0] as List<CustomerProfileDto>;
      _tiers = results[1] as List<TierDto>;
      _emit();
    } catch (e) {
      emit(CpError('Không tải được danh sách: $e'));
    }
  }

  void search(String q) {
    _query = q;
    _emit();
  }

  void _emit() => emit(CpLoaded(_profiles, _tiers, query: _query));

  Future<void> addPoints(String id, int points, String note) async {
    await _repo.addPoints(id, points, note: note.isEmpty ? null : note);
    await load();
  }

  Future<void> redeemPoints(String id, int points, String note) async {
    await _repo.redeemPoints(id, points, note: note.isEmpty ? null : note);
    await load();
  }

  Future<void> updateProfile(String id, UpdateCustomerProfileDto dto) async {
    await _repo.updateProfile(id, dto);
    await load();
  }

  Future<void> createProfile(String customerId, {String? tierId}) async {
    await _repo.createProfile(customerId, tierId: tierId);
    await load();
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────

class CustomerProfilesScreen extends StatelessWidget {
  const CustomerProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CustomerProfileCubit()..load(),
      child: const _CustomerProfilesView(),
    );
  }
}

class _CustomerProfilesView extends StatefulWidget {
  const _CustomerProfilesView();
  @override
  State<_CustomerProfilesView> createState() => _CustomerProfilesViewState();
}

class _CustomerProfilesViewState extends State<_CustomerProfilesView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerProfileCubit, CpState>(
      builder: (ctx, state) {
        return Column(
          children: [
            // Search bar
            Container(
              color: const Color(0xFF004D40),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => ctx.read<CustomerProfileCubit>().search(v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tìm theo ID hoặc Tier...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchCtrl.clear();
                          ctx.read<CustomerProfileCubit>().search('');
                        },
                      )
                    : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            // Content
            Expanded(child: _buildContent(ctx, state)),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext ctx, CpState state) {
    if (state is CpLoading) return const Center(child: CircularProgressIndicator());
    if (state is CpError) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(state.msg, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
            onPressed: () => ctx.read<CustomerProfileCubit>().load(),
          ),
        ],
      ));
    }
    if (state is CpLoaded) {
      final profiles = state.filtered;
      if (profiles.isEmpty) {
        return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              state.query.isNotEmpty ? 'Không tìm thấy kết quả' : 'Chưa có customer profile nào',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ));
      }
      return RefreshIndicator(
        onRefresh: () => ctx.read<CustomerProfileCubit>().load(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: profiles.length,
          itemBuilder: (_, i) => _ProfileCard(
            profile: profiles[i],
            tiers: state.tiers,
            onTap: () => _showDetail(ctx, profiles[i], state.tiers),
          ),
        ),
      );
    }
    return const SizedBox();
  }

  void _showDetail(BuildContext ctx, CustomerProfileDto p, List<TierDto> tiers) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: ctx.read<CustomerProfileCubit>(),
        child: _ProfileDetailSheet(profile: p, tiers: tiers),
      ),
    );
  }
}

// ─── Profile Card ─────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final CustomerProfileDto profile;
  final List<TierDto> tiers;
  final VoidCallback onTap;
  const _ProfileCard({required this.profile, required this.tiers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(profile.tierDisplayName);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar tier
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [tierColor.withValues(alpha: 0.8), tierColor]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: tierColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(profile.tierDisplayName, style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${profile.id.length > 16 ? '${profile.id.substring(0, 16)}...' : profile.id}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        _chip(Icons.stars_rounded, '${profile.availablePoints} pts', Colors.amber),
                        const SizedBox(width: 8),
                        _chip(Icons.local_car_wash_rounded, '${profile.totalVisits} lượt', Colors.blue),
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]);
  }

  Color _tierColor(String tier) {
    final t = tier.toLowerCase();
    if (t.contains('gold') || t.contains('vàng')) return const Color(0xFFF59E0B);
    if (t.contains('silver') || t.contains('bạc')) return const Color(0xFF64748B);
    if (t.contains('platinum')) return const Color(0xFF7C3AED);
    if (t.contains('diamond')) return const Color(0xFF06B6D4);
    return const Color(0xFF004D40);
  }
}

// ─── Detail Bottom Sheet ──────────────────────────────────────────────────

class _ProfileDetailSheet extends StatefulWidget {
  final CustomerProfileDto profile;
  final List<TierDto> tiers;
  const _ProfileDetailSheet({required this.profile, required this.tiers});

  @override
  State<_ProfileDetailSheet> createState() => _ProfileDetailSheetState();
}

class _ProfileDetailSheetState extends State<_ProfileDetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: Color(0xFF004D40)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.tierDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(p.id.length > 24 ? '${p.id.substring(0, 24)}...' : p.id, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                )),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _stat('${p.availablePoints}', 'Điểm khả dụng', Colors.amber),
                _stat('${p.lifetimePoints}', 'Điểm trọn đời', Colors.deepOrange),
                _stat('${p.totalVisits}', 'Lượt rửa', Colors.blue),
                _stat('${(p.totalSpending / 1000).toStringAsFixed(0)}K', 'Tổng chi', Colors.green),
              ]),
            ),
            const SizedBox(height: 8),
            // Tabs
            TabBar(
              controller: _tabs,
              labelColor: const Color(0xFF004D40),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF004D40),
              tabs: const [Tab(text: 'Thông tin'), Tab(text: 'Điểm thưởng')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _InfoTab(profile: p, tiers: widget.tiers),
                  _PointsTab(profile: p),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─── Info Tab ─────────────────────────────────────────────────────────────

class _InfoTab extends StatefulWidget {
  final CustomerProfileDto profile;
  final List<TierDto> tiers;
  const _InfoTab({required this.profile, required this.tiers});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  String? _selectedTierId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedTierId = widget.profile.currentTierId;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoRow('Customer ID', p.id),
        _infoRow('Tier hiện tại', p.tierDisplayName),
        if (p.tierUpgradedAt != null)
          _infoRow('Nâng tier lần cuối', _fmtDate(p.tierUpgradedAt!)),
        if (p.lastTierReviewDate != null)
          _infoRow('Xét duyệt tier gần nhất', _fmtDate(p.lastTierReviewDate!)),
        if (p.createdAt != null)
          _infoRow('Ngày tạo profile', _fmtDate(p.createdAt!)),
        if (p.updatedAt != null)
          _infoRow('Cập nhật lần cuối', _fmtDate(p.updatedAt!)),
        if (p.updateBy != null)
          _infoRow('Cập nhật bởi', p.updateBy!),
        const Divider(height: 32),
        const Text('Thay đổi Tier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedTierId,
          decoration: InputDecoration(
            labelText: 'Chọn Tier',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: widget.tiers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
          onChanged: (v) => setState(() => _selectedTierId = v),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF004D40),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _saving ? null : _saveTier,
          child: _saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Lưu thay đổi Tier'),
        ),
      ],
    );
  }

  Future<void> _saveTier() async {
    if (_selectedTierId == null) return;
    setState(() => _saving = true);
    try {
      await context.read<CustomerProfileCubit>().updateProfile(
        widget.profile.id,
        UpdateCustomerProfileDto(
          currentTierId: _selectedTierId,
          availablePoints: widget.profile.availablePoints,
          lifetimePoints: widget.profile.lifetimePoints,
          totalVisits: widget.profile.totalVisits,
          totalSpending: widget.profile.totalSpending,
        ),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật tier thành công!'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thất bại!'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─── Points Tab ───────────────────────────────────────────────────────────

class _PointsTab extends StatefulWidget {
  final CustomerProfileDto profile;
  const _PointsTab({required this.profile});

  @override
  State<_PointsTab> createState() => _PointsTabState();
}

class _PointsTabState extends State<_PointsTab> {
  final _pointsCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _adding = false;
  bool _redeeming = false;

  @override
  void dispose() {
    _pointsCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Điểm hiện tại
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00695C)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _pointStat('${widget.profile.availablePoints}', 'Điểm khả dụng', Icons.stars_rounded),
              Container(width: 1, height: 40, color: Colors.white30),
              _pointStat('${widget.profile.lifetimePoints}', 'Điểm trọn đời', Icons.workspace_premium_rounded),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Nhập điểm / Số điểm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        TextField(
          controller: _pointsCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Số điểm *',
            prefixIcon: const Icon(Icons.stars_rounded, color: Colors.amber),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: 'Ghi chú (tuỳ chọn)',
            prefixIcon: const Icon(Icons.note_rounded, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _adding ? null : _doAdd,
              icon: _adding
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.add_circle_outline),
              label: const Text('Cộng điểm'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _redeeming ? null : _doRedeem,
              icon: _redeeming
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.remove_circle_outline),
              label: const Text('Đổi điểm'),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _pointStat(String value, String label, IconData icon) {
    return Column(children: [
      Icon(icon, color: Colors.amber, size: 28),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }

  Future<void> _doAdd() async {
    final pts = int.tryParse(_pointsCtrl.text);
    if (pts == null || pts <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập số điểm hợp lệ'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _adding = true);
    try {
      await context.read<CustomerProfileCubit>().addPoints(widget.profile.id, pts, _noteCtrl.text);
      if (mounted) {
        _pointsCtrl.clear(); _noteCtrl.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã cộng $pts điểm thành công!'), backgroundColor: Colors.green));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cộng điểm thất bại!'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _doRedeem() async {
    final pts = int.tryParse(_pointsCtrl.text);
    if (pts == null || pts <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập số điểm hợp lệ'), backgroundColor: Colors.red));
      return;
    }
    if (pts > widget.profile.availablePoints) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không đủ điểm! Hiện có ${widget.profile.availablePoints} điểm'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _redeeming = true);
    try {
      await context.read<CustomerProfileCubit>().redeemPoints(widget.profile.id, pts, _noteCtrl.text);
      if (mounted) {
        _pointsCtrl.clear(); _noteCtrl.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã đổi $pts điểm thành công!'), backgroundColor: Colors.green));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi điểm thất bại!'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }
}
