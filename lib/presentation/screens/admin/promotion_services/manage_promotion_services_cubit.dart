import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/promotion_model.dart';
import '../../../../data/models/tier_model.dart';
import '../../../../data/repositories/promotion_repository.dart';
import '../../../../data/repositories/customer_profile_repository.dart';
import '../../../../core/utils/jwt_helper.dart'; // Dùng AuthSession thay vì UserSession

abstract class ManagePromotionState {}
class MPromotionLoading extends ManagePromotionState {}
class MPromotionLoaded extends ManagePromotionState {
  final List<PromotionDto> promotions;
  final List<TierDto> tiers;
  MPromotionLoaded(this.promotions, this.tiers);
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
      final tiers = await CustomerProfileRepository().getAllTiers();
      emit(MPromotionLoaded(list, tiers));
    } catch (e) {
      emit(MPromotionError("Lỗi tải dữ liệu: $e"));
    }
  }
  Future<void> updatePromotion(PromotionDto dto) async {
    await _repo.updatePromotion(dto.id, dto.toJson());
    await load();
  }

  Future<void> addPromotion(PromotionDto dto) async {
    // Dùng AuthSession (FlutterSecureStorage) — cùng storage với login
    final userId = await AuthSession.getUserId();

    final Map<String, dynamic> data = dto.toJson();
    data.remove('id');
    data['createdBy'] = userId;

    // ignore: avoid_print
    print('[PROMOTION] Sending create payload: $data');
    try {
      await _repo.createPromotion(data);
      load();
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[PROMOTION] Create failed with status: ${e.response?.statusCode}');
      // ignore: avoid_print
      print('[PROMOTION] Create failed with response data: ${e.response?.data}');
      emit(MPromotionError("Lỗi tạo khuyến mãi: ${e.response?.statusCode} - ${e.response?.data ?? e.message}"));
    } catch (e) {
      emit(MPromotionError("Lỗi: $e"));
    }
  }
  Future<void> toggleStatus(PromotionDto p) async {
    final data = p.toJson();
    data['isActive'] = !p.isActive;
    await _repo.updatePromotion(p.id, data);
    load();
  }

  Future<void> deletePromotion(String id) async {
    await _repo.deletePromotion(id);
    await load();
  }
}