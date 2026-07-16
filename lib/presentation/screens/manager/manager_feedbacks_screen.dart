import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/feedback_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../../../data/repositories/user_repository.dart';

const _managerGreen = Color(0xFF004D40);

// ─── Cubit ────────────────────────────────────────────────────────────────

abstract class ManagerFeedbackState {}

class ManagerFeedbackLoading extends ManagerFeedbackState {}

class ManagerFeedbackLoaded extends ManagerFeedbackState {
  final List<FeedbackDto> feedbacks;
  final List<UserDto> customers;
  final String? message;

  ManagerFeedbackLoaded({
    required this.feedbacks,
    required this.customers,
    this.message,
  });

  double get averageRating =>
      feedbacks.isEmpty ? 0 : feedbacks.map((f) => f.rating).reduce((a, b) => a + b) / feedbacks.length;
}

class ManagerFeedbackError extends ManagerFeedbackState {
  final String msg;
  ManagerFeedbackError(this.msg);
}

class ManagerFeedbackCubit extends Cubit<ManagerFeedbackState> {
  final FeedbackRepository _feedbackRepo = FeedbackRepository();
  final UserRepository _userRepo = UserRepository();

  ManagerFeedbackCubit() : super(ManagerFeedbackLoading());

  Future<void> load({String? message}) async {
    emit(ManagerFeedbackLoading());
    try {
      final results = await Future.wait([
        _feedbackRepo.getAllFeedbacks(),
        _userRepo.getAllUsers(),
      ]);
      final feedbacks = results[0] as List<FeedbackDto>;
      final customers = (results[1] as List<UserDto>)
          .where((u) => u.isCustomer)
          .toList();

      feedbacks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(ManagerFeedbackLoaded(feedbacks: feedbacks, customers: customers, message: message));
    } on DioException catch (e) {
      emit(ManagerFeedbackError(e.response?.data?['message'] ?? 'Không tải được đánh giá'));
    } catch (_) {
      emit(ManagerFeedbackError('Không tải được đánh giá'));
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────

enum _RatingFilter { all, five, four, three, low }

class ManagerFeedbacksPage extends StatefulWidget {
  const ManagerFeedbacksPage({super.key});

  @override
  State<ManagerFeedbacksPage> createState() => _ManagerFeedbacksPageState();
}

class _ManagerFeedbacksPageState extends State<ManagerFeedbacksPage> {
  final _searchCtrl = TextEditingController();
  _RatingFilter _ratingFilter = _RatingFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  UserDto? _findCustomer(ManagerFeedbackLoaded state, String customerId) {
    for (final u in state.customers) {
      if (u.id == customerId) return u;
    }
    return null;
  }

  List<FeedbackDto> _applyFilters(ManagerFeedbackLoaded state) {
    final query = _searchCtrl.text.trim().toLowerCase();
    var list = state.feedbacks;

    switch (_ratingFilter) {
      case _RatingFilter.five:
        list = list.where((f) => f.rating == 5).toList();
      case _RatingFilter.four:
        list = list.where((f) => f.rating == 4).toList();
      case _RatingFilter.three:
        list = list.where((f) => f.rating == 3).toList();
      case _RatingFilter.low:
        list = list.where((f) => f.rating <= 2).toList();
      case _RatingFilter.all:
        break;
    }

    if (query.isEmpty) return list;

    return list.where((f) {
      final customer = _findCustomer(state, f.customerId);
      final haystack = [
        f.comment ?? '',
        f.bookingId,
        customer?.fullName ?? '',
        customer?.email ?? '',
        '${f.rating}',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ManagerFeedbackCubit, ManagerFeedbackState>(
      listener: (ctx, state) {
        if (state is ManagerFeedbackError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.msg), backgroundColor: Colors.red),
          );
        } else if (state is ManagerFeedbackLoaded && state.message != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.message!), backgroundColor: Colors.green),
          );
        }
      },
      builder: (ctx, state) {
        if (state is ManagerFeedbackLoading) {
          return const Center(child: CircularProgressIndicator(color: _managerGreen));
        }
        if (state is ManagerFeedbackError) {
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
                  onPressed: () => ctx.read<ManagerFeedbackCubit>().load(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        if (state is! ManagerFeedbackLoaded) return const SizedBox();

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
                  hintText: 'Tìm theo khách, booking, nội dung...',
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
            _buildRatingFilters(),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty(state.feedbacks.isNotEmpty)
                  : RefreshIndicator(
                      color: _managerGreen,
                      onRefresh: () => ctx.read<ManagerFeedbackCubit>().load(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final feedback = filtered[i];
                          final customer = _findCustomer(state, feedback.customerId);
                          return _FeedbackCard(
                            feedback: feedback,
                            customerName: customer?.fullName ?? 'Khách #${feedback.customerId.substring(0, 8)}',
                            customerEmail: customer?.email ?? '',
                            onTap: () => _showDetail(ctx, feedback, customer),
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

  Widget _buildHeader(ManagerFeedbackLoaded state) {
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
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.reviews_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phản hồi khách hàng', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${state.feedbacks.length} đánh giá',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      state.feedbacks.isEmpty
                          ? 'Chưa có điểm trung bình'
                          : 'TB ${state.averageRating.toStringAsFixed(1)} / 5',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _ratingChip('Tất cả', _RatingFilter.all),
          const SizedBox(width: 8),
          _ratingChip('5 sao', _RatingFilter.five),
          const SizedBox(width: 8),
          _ratingChip('4 sao', _RatingFilter.four),
          const SizedBox(width: 8),
          _ratingChip('3 sao', _RatingFilter.three),
          const SizedBox(width: 8),
          _ratingChip('≤2 sao', _RatingFilter.low),
        ],
      ),
    );
  }

  Widget _ratingChip(String label, _RatingFilter value) {
    final selected = _ratingFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _ratingFilter = value),
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
          Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            isFilteredEmpty ? 'Không có đánh giá phù hợp' : 'Chưa có phản hồi nào',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext ctx, FeedbackDto feedback, UserDto? customer) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chi tiết đánh giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < feedback.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _detailRow('Khách hàng', customer?.fullName ?? feedback.customerId),
            _detailRow('Email', customer?.email ?? '—'),
            _detailRow('Booking', '#${feedback.bookingId.length >= 8 ? feedback.bookingId.substring(0, 8).toUpperCase() : feedback.bookingId.toUpperCase()}'),
            _detailRow('Ngày gửi', _fmtDate(feedback.createdAt)),
            const SizedBox(height: 12),
            const Text('Nhận xét', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                feedback.comment?.isNotEmpty == true ? feedback.comment! : 'Không có nhận xét',
                style: TextStyle(color: Colors.grey.shade800, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackDto feedback;
  final String customerName;
  final String customerEmail;
  final VoidCallback onTap;

  const _FeedbackCard({
    required this.feedback,
    required this.customerName,
    required this.customerEmail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _managerGreen.withValues(alpha: 0.12),
                  child: Text(
                    customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                    style: const TextStyle(color: _managerGreen, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (customerEmail.isNotEmpty)
                        Text(customerEmail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < feedback.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ],
            ),
            if (feedback.comment?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                feedback.comment!,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.35),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_note_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Booking #${feedback.bookingId.length >= 8 ? feedback.bookingId.substring(0, 8).toUpperCase() : feedback.bookingId.toUpperCase()}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  _fmtDate(feedback.createdAt),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
