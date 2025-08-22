import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import '../lib/models/attendance_record.dart';

// Test helper function that mimics the What If calculation logic
Map<String, dynamic> calculateWhatIf(List<AttendanceRecord> records, String simulatedStatus) {
  try {
    // Validate input
    if (simulatedStatus != 'present' && simulatedStatus != 'absent') {
      throw ArgumentError('Invalid status: $simulatedStatus');
    }
    
    // Create temporary record list with simulation
    final tempRecords = List<AttendanceRecord>.from(records);
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    
    // Check if record exists for today
    final existingIndex = tempRecords.indexWhere(
      (r) => DateFormat('yyyy-MM-dd').format(r.date) == todayStr
    );
    
    if (existingIndex >= 0) {
      // Replace existing record with simulated status
      tempRecords[existingIndex] = AttendanceRecord(
        id: tempRecords[existingIndex].id,
        classId: tempRecords[existingIndex].classId,
        studentRollNumber: tempRecords[existingIndex].studentRollNumber,
        studentName: tempRecords[existingIndex].studentName,
        date: tempRecords[existingIndex].date,
        status: simulatedStatus,
        professorEmail: tempRecords[existingIndex].professorEmail,
        subjectName: tempRecords[existingIndex].subjectName,
        collegeName: tempRecords[existingIndex].collegeName,
        branchName: tempRecords[existingIndex].branchName,
        semesterName: tempRecords[existingIndex].semesterName,
        classNumber: tempRecords[existingIndex].classNumber,
        createdAt: tempRecords[existingIndex].createdAt,
      );
    } else {
      // Add new simulated record for today
      tempRecords.add(AttendanceRecord(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        classId: 'temp_class',
        studentRollNumber: 'TEST001',
        studentName: 'Test Student',
        date: today,
        status: simulatedStatus,
        professorEmail: 'temp_professor',
        subjectName: 'Test Subject',
        classNumber: 1,
      ));
    }
    
    // Calculate new statistics
    final totalClasses = tempRecords.length;
    final presentCount = tempRecords.where((r) => r.status == 'present').length;
    final absentCount = totalClasses - presentCount;
    final newPercentage = totalClasses > 0 ? (presentCount / totalClasses) * 100 : 0;
    
    // Calculate current statistics for comparison
    final currentTotal = records.length;
    final currentPresent = records.where((r) => r.status == 'present').length;
    final currentPercentage = currentTotal > 0 ? (currentPresent / currentTotal) * 100 : 0;
    
    final percentageChange = newPercentage - currentPercentage;
    final isImprovement = percentageChange > 0;
    final isBelow75Percent = newPercentage < 75.0;
    
    return {
      'currentPercentage': currentPercentage,
      'projectedPercentage': newPercentage,
      'percentageChange': percentageChange,
      'totalClasses': totalClasses,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'isImprovement': isImprovement,
      'isBelow75Percent': isBelow75Percent,
    };
  } catch (e) {
    // Return safe defaults on error
    return {
      'currentPercentage': 0.0,
      'projectedPercentage': 0.0,
      'percentageChange': 0.0,
      'totalClasses': 0,
      'presentCount': 0,
      'absentCount': 0,
      'isImprovement': false,
      'isBelow75Percent': true,
      'error': e.toString(),
    };
  }
}

void main() {
  group('What If Calculation Engine Tests', () {
    late List<AttendanceRecord> testRecords;
    
    setUp(() {
      // Create test attendance records
      testRecords = [
        AttendanceRecord(
          id: '1',
          classId: 'class1',
          studentRollNumber: 'TEST001',
          studentName: 'Test Student',
          date: DateTime.now().subtract(const Duration(days: 5)),
          status: 'present',
          professorEmail: 'prof@test.com',
          subjectName: 'Test Subject',
        ),
        AttendanceRecord(
          id: '2',
          classId: 'class1',
          studentRollNumber: 'TEST001',
          studentName: 'Test Student',
          date: DateTime.now().subtract(const Duration(days: 4)),
          status: 'present',
          professorEmail: 'prof@test.com',
          subjectName: 'Test Subject',
        ),
        AttendanceRecord(
          id: '3',
          classId: 'class1',
          studentRollNumber: 'TEST001',
          studentName: 'Test Student',
          date: DateTime.now().subtract(const Duration(days: 3)),
          status: 'absent',
          professorEmail: 'prof@test.com',
          subjectName: 'Test Subject',
        ),
        AttendanceRecord(
          id: '4',
          classId: 'class1',
          studentRollNumber: 'TEST001',
          studentName: 'Test Student',
          date: DateTime.now().subtract(const Duration(days: 2)),
          status: 'present',
          professorEmail: 'prof@test.com',
          subjectName: 'Test Subject',
        ),
      ];
    });

    test('should calculate correct percentage for present simulation', () {
      final result = calculateWhatIf(testRecords, 'present');
      
      expect(result['currentPercentage'], 75.0); // 3 present out of 4 = 75%
      expect(result['projectedPercentage'], 80.0); // 4 present out of 5 = 80%
      expect(result['percentageChange'], 5.0);
      expect(result['isImprovement'], true);
      expect(result['isBelow75Percent'], false);
      expect(result['totalClasses'], 5);
      expect(result['presentCount'], 4);
      expect(result['absentCount'], 1);
    });

    test('should calculate correct percentage for absent simulation', () {
      final result = calculateWhatIf(testRecords, 'absent');
      
      expect(result['currentPercentage'], 75.0); // 3 present out of 4 = 75%
      expect(result['projectedPercentage'], 60.0); // 3 present out of 5 = 60%
      expect(result['percentageChange'], -15.0);
      expect(result['isImprovement'], false);
      expect(result['isBelow75Percent'], true);
      expect(result['totalClasses'], 5);
      expect(result['presentCount'], 3);
      expect(result['absentCount'], 2);
    });

    test('should handle empty attendance records', () {
      final result = calculateWhatIf([], 'present');
      
      expect(result['currentPercentage'], 0.0);
      expect(result['projectedPercentage'], 100.0); // 1 present out of 1 = 100%
      expect(result['percentageChange'], 100.0);
      expect(result['isImprovement'], true);
      expect(result['isBelow75Percent'], false);
      expect(result['totalClasses'], 1);
      expect(result['presentCount'], 1);
      expect(result['absentCount'], 0);
    });

    test('should handle single record scenario', () {
      final singleRecord = [testRecords.first];
      final result = calculateWhatIf(singleRecord, 'absent');
      
      expect(result['currentPercentage'], 100.0); // 1 present out of 1 = 100%
      expect(result['projectedPercentage'], 50.0); // 1 present out of 2 = 50%
      expect(result['percentageChange'], -50.0);
      expect(result['isImprovement'], false);
      expect(result['isBelow75Percent'], true);
    });

    test('should handle 100% attendance scenario', () {
      final perfectRecords = testRecords.map((r) => AttendanceRecord(
        id: r.id,
        classId: r.classId,
        studentRollNumber: r.studentRollNumber,
        studentName: r.studentName,
        date: r.date,
        status: 'present', // All present
        professorEmail: r.professorEmail,
        subjectName: r.subjectName,
      )).toList();
      
      final result = calculateWhatIf(perfectRecords, 'absent');
      
      expect(result['currentPercentage'], 100.0);
      expect(result['projectedPercentage'], 80.0); // 4 present out of 5 = 80%
      expect(result['percentageChange'], -20.0);
      expect(result['isImprovement'], false);
      expect(result['isBelow75Percent'], false);
    });

    test('should handle 0% attendance scenario', () {
      final zeroRecords = testRecords.map((r) => AttendanceRecord(
        id: r.id,
        classId: r.classId,
        studentRollNumber: r.studentRollNumber,
        studentName: r.studentName,
        date: r.date,
        status: 'absent', // All absent
        professorEmail: r.professorEmail,
        subjectName: r.subjectName,
      )).toList();
      
      final result = calculateWhatIf(zeroRecords, 'present');
      
      expect(result['currentPercentage'], 0.0);
      expect(result['projectedPercentage'], 20.0); // 1 present out of 5 = 20%
      expect(result['percentageChange'], 20.0);
      expect(result['isImprovement'], true);
      expect(result['isBelow75Percent'], true);
    });

    test('should handle invalid status input', () {
      final result = calculateWhatIf(testRecords, 'invalid');
      
      expect(result.containsKey('error'), true);
      expect(result['error'], contains('Invalid status'));
      expect(result['currentPercentage'], 0.0);
      expect(result['projectedPercentage'], 0.0);
    });

    test('should replace existing record for today', () {
      // Add a record for today
      final todayRecord = AttendanceRecord(
        id: '5',
        classId: 'class1',
        studentRollNumber: 'TEST001',
        studentName: 'Test Student',
        date: DateTime.now(),
        status: 'present',
        professorEmail: 'prof@test.com',
        subjectName: 'Test Subject',
      );
      
      final recordsWithToday = [...testRecords, todayRecord];
      final result = calculateWhatIf(recordsWithToday, 'absent');
      
      // Should replace today's record, not add a new one
      expect(result['totalClasses'], 5); // Same total, not 6
      expect(result['presentCount'], 3); // One less present (today changed to absent)
      expect(result['projectedPercentage'], 60.0); // 3 present out of 5 = 60%
    });
  });
}