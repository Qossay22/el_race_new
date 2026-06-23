import 'package:get/get.dart';
import '../view_model/instruction_view_model.dart';

class InstructionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InstructionViewController>(
      () => InstructionViewController(),
    );
  }
}
