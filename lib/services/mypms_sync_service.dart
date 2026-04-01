// lib/services/mypms_sync_service.dart
//
// Sync bridge between SmartBayu and MyPMS.
// - Payroll → MyPMS accounting journal entries
// - Attendance → MyPMS shift assignments
//
// Uses the MyPMS FastAPI backend directly via HTTP.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'supabase_service.dart';

class MyPmsSyncService {
  MyPmsSyncService._();
  static final instance = MyPmsSyncService._();

  // MyPMS backend URL — override via dart-define for production
  static const _baseUrl = String.fromEnvironment(
    'MYPMS_API_URL',
    defaultValue: 'https://resort-automation-077ba29abad0.herokuapp.com',
  );

  /// Post approved payroll to MyPMS accounting as journal entries.
  ///
  /// Creates:
  ///   DR  Salary Expense
  ///   DR  EPF Employer
  ///   DR  SOCSO/EIS Employer
  ///   CR  Salary Payable
  ///   CR  EPF Payable
  ///   CR  SOCSO/EIS Payable
  Future<String?> postPayrollToAccounting({
    required String payslipId,
    required String staffName,
    required String monthLabel,
    required double basicSalary,
    required double totalAllowances,
    required double epfEmployee,
    required double epfEmployer,
    required double socsoEmployee,
    required double socsoEmployer,
    required double eisEmployee,
    required double netPay,
    required String companyId,
  }) async {
    try {
      final totalGross = basicSalary + totalAllowances;
      final totalEmployerContrib = epfEmployer + socsoEmployer;

      final body = {
        'source': 'smartbayu',
        'source_ref': payslipId,
        'company_id': companyId,
        'description': 'Payroll - $staffName ($monthLabel)',
        'entries': [
          {'account_code': '5100', 'description': 'Salary Expense', 'debit': totalGross, 'credit': 0},
          {'account_code': '5110', 'description': 'EPF Employer', 'debit': epfEmployer, 'credit': 0},
          {'account_code': '5120', 'description': 'SOCSO/EIS Employer', 'debit': socsoEmployer, 'credit': 0},
          {'account_code': '2100', 'description': 'Salary Payable', 'debit': 0, 'credit': netPay},
          {'account_code': '2110', 'description': 'EPF Payable', 'debit': 0, 'credit': epfEmployee + epfEmployer},
          {'account_code': '2120', 'description': 'SOCSO/EIS Payable', 'debit': 0, 'credit': socsoEmployee + socsoEmployer + eisEmployee},
        ],
      };

      final resp = await http.post(
        Uri.parse('$_baseUrl/api/journal/from-smartbayu'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        return data['journal_id'] as String?;
      } else {
        debugPrint('MyPMS sync failed: ${resp.statusCode} ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('MyPMS sync error: $e');
      return null;
    }
  }

  /// Sync daily attendance summary to MyPMS for shift tracking.
  Future<bool> syncAttendance({
    required String staffId,
    required String date,
    required double hoursWorked,
    required double overtimeHours,
    required String status,
    required String companyId,
  }) async {
    try {
      final body = {
        'source': 'smartbayu',
        'staff_id': staffId,
        'company_id': companyId,
        'date': date,
        'hours_worked': hoursWorked,
        'overtime_hours': overtimeHours,
        'status': status,
      };

      final resp = await http.post(
        Uri.parse('$_baseUrl/api/hr/attendance-sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      debugPrint('Attendance sync error: $e');
      return false;
    }
  }
}
