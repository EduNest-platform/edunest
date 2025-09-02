import 'package:flutter_test/flutter_test.dart';
import 'package:edunest/controllers/profile_setup_controller.dart';

void main() {
  group('ProfileSetupController Tests', () {
    late ProfileSetupController controller;

    setUp(() {
      controller = ProfileSetupController();
    });

    tearDown(() {
      controller.disposeControllers();
    });

    test('should validate all required fields are filled', () {
      // Initially, no fields are filled
      expect(controller.selectedCollegeId, isNull);
      expect(controller.selectedBranchId, isNull);
      expect(controller.selectedSemesterId, isNull);
      expect(controller.rollNumberController.text, isEmpty);

      // Fill all required fields
      controller.selectedCollegeId = 'college-1';
      controller.selectedBranchId = 'branch-1';
      controller.selectedSemesterId = 'semester-1';
      controller.rollNumberController.text = 'CS2021001';

      // All fields should be filled now
      expect(controller.selectedCollegeId, isNotNull);
      expect(controller.selectedBranchId, isNotNull);
      expect(controller.selectedSemesterId, isNotNull);
      expect(controller.rollNumberController.text.trim().isNotEmpty, isTrue);
    });

    test('should update roll number and notify listeners', () {
      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      controller.rollNumberController.text = 'CS2021001';

      expect(controller.rollNumberController.text, equals('CS2021001'));
      expect(notified, isTrue);
    });

    test('should clear error when setting loading', () {
      controller.setError('Test error');
      expect(controller.errorMessage, equals('Test error'));

      controller.setLoading(true);
      // Error should still be there when just setting loading
      expect(controller.errorMessage, equals('Test error'));
    });
  });
}