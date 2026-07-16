import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/promotion_model.dart';
import '../../../../data/repositories/promotion_repository.dart';
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
      emit(MPromotionError("Lỗi tải dữ liệu: $e"));
    }
  }
  Future<void> updatePromotion(PromotionDto dto) async {
    await _repo.updatePromotion(dto.id, dto.toJson());
    await load();
  }

  Future<void> addPromotion(PromotionDto dto) async {
    final userId = await UserSession.getUserId();

    // Lấy dữ liệu để gửi lên (Loại bỏ ID vì backend không cần)
    final Map<String, dynamic> data = dto.toJson();
    data.remove("id"); // Loại bỏ ID vì backend dùng CreatePromotionDto
    data['createdBy'] = userId;

    await _repo.createPromotion(data);
    load();
  }
  Future<void> toggleStatus(PromotionDto p) async {
    final data = p.toJson();
    data['IsActive'] = !p.isActive; // Phải dùng 'IsActive' (viết hoa chữ I)
    await _repo.updatePromotion(p.id, data);
    load();
  }

  Future<void> deletePromotion(String id) async {
    await _repo.deletePromotion(id);
    await load();
  }
}