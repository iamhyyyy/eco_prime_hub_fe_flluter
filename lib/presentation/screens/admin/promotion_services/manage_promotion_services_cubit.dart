import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/promotion_model.dart';
import '../../../../data/repositories/promotion_repository.dart';
// Import service chứa session của bạn
import '../../../../data/services/user_session.dart';

abstract class ManagePromotionState {}

class MPromotionLoading extends ManagePromotionState {}

class MPromotionLoaded extends ManagePromotionState {
  final List<PromotionDto> promotions;
  MPromotionLoaded(this.promotions);
}

class MPromotionError extends ManagePromotionState {
  final String message;
  MPromotionError(this.message);
}

class ManagePromotionCubit extends Cubit<ManagePromotionState> {
  final PromotionRepository _repo = PromotionRepository();

  ManagePromotionCubit() : super(MPromotionLoading());

  Future<void> load() async {
    emit(MPromotionLoading());
    try {
      final list = await _repo.getAllPromotions();
      emit(MPromotionLoaded(list));
    } catch (e) {
      emit(MPromotionError("Không thể tải dữ liệu: $e"));
    }
  }

  /// Hàm add tự động lấy ID người tạo từ Session
  Future<void> addPromotion(PromotionDto dto) async {
    final userId = await UserSession.getUserId();
    if (userId == null) {
      emit(MPromotionError("Phiên đăng nhập đã hết hạn"));
      return;
    }

    // Chuyển đổi DTO sang Map để gửi đi, thêm trường createdBy vào đây
    final data = dto.toJson();
    data['createdBy'] = userId;

    await _repo.createPromotion(data);
    await load(); // Tự động load lại sau khi thêm thành công
  }

  Future<void> updatePromotion(PromotionDto dto) async {
    // Nếu cần kiểm tra quyền chỉnh sửa, bạn cũng có thể lấy userId ở đây
    await _repo.updatePromotion(dto.id, dto.toJson());
    await load();
  }

  Future<void> toggleStatus(PromotionDto p) async {
    final data = p.toJson();
    data['isActive'] = !p.isActive;
    await _repo.updatePromotion(p.id, data);
    await load();
  }

  Future<void> deletePromotion(String id) async {
    await _repo.deletePromotion(id);
    await load();
  }
}