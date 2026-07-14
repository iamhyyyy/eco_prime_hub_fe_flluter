import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/wash_service_model.dart';
import '../../../../data/repositories/wash_service_repository.dart';

abstract class ManageServiceState {}
class MServiceLoading extends ManageServiceState {}
class MServiceLoaded extends ManageServiceState {
  final List<WashServiceDto> services;
  MServiceLoaded(this.services);
}

class ManageWashServiceCubit extends Cubit<ManageServiceState> {
  final WashServiceRepository _repo = WashServiceRepository();
  ManageWashServiceCubit() : super(MServiceLoading());

  Future<void> load() async {
    emit(MServiceLoading());
    try {
      final list = await _repo.getAllServices();
      // Sắp xếp: Active lên trên, Inactive xuống dưới
      list.sort((a, b) => b.isActive == a.isActive ? 0 : (a.isActive ? -1 : 1));
      emit(MServiceLoaded(list));
    } catch (e) {
      print("Lỗi load data: $e");
    }
  }

  Future<void> addService(WashServiceDto dto) async {
    await _repo.createService(dto);
    load();
  }
  // Hàm Update: Cập nhật thông tin dịch vụ
  Future<void> updateService(WashServiceDto dto) async {
    try {
      // Gọi repository truyền vào ID và dữ liệu đã chuyển sang Map
      await _repo.updateService(dto.id, dto.toJson());

      // Sau khi update xong thì load lại danh sách để UI cập nhật ngay lập tức
      await load();
    } catch (error) {
      print("Lỗi khi cập nhật dịch vụ: $error");
    }
  }
  // HÀM TOGGLE: Nhận toàn bộ object để không làm mất data cũ
  Future<void> toggleServiceStatus(WashServiceDto service) async {
    try {
      // 1. Chuyển object hiện tại thành Map JSON để giữ lại toàn bộ thuộc tính
      final updateData = service.toJson();

      // 2. Chỉ thay đổi trạng thái isActive
      updateData['isActive'] = !service.isActive;

      // 3. Gửi toàn bộ dữ liệu lên Backend
      await _repo.updateService(service.id, updateData);
      load();
    } catch (error) {
      print("Lỗi cập nhật trạng thái: $error");
    }
  }
 Future<void> getServiceByID(WashServiceDto dto) async{
    await _repo.getServiceById(dto.id);
 }
}