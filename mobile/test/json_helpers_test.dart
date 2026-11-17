import 'package:flutter_test/flutter_test.dart';
import 'package:company_os/core/utils/json_helpers.dart';
import 'package:company_os/features/deals/data/models/deal_model.dart';
import 'package:company_os/features/tasks/data/models/task_model.dart';
import 'package:company_os/features/finance/data/models/transaction_model.dart';

void main() {
  group('JsonHelpers Tests', () {
    test('extractString never crashes when entity is a plain String instead of Map', () {
      // This reproduces the exact bug: type 'String' is not a subtype of type 'int' of 'index'
      const rawAuthorString = 'Иван Иванов';
      final result = JsonHelpers.extractString(rawAuthorString, fallback: 'Сотрудник');
      expect(result, equals('Иван Иванов'));
    });

    test('extractString extracts from Map correctly', () {
      final rawMap = {'fullName': 'Иван Иванов', 'id': 'u1'};
      final result = JsonHelpers.extractString(rawMap, preferredKeys: ['fullName', 'name']);
      expect(result, equals('Иван Иванов'));
    });

    test('extractString handles null safely', () {
      final result = JsonHelpers.extractString(null, fallback: 'Сотрудник');
      expect(result, equals('Сотрудник'));
    });

    test('toMap handles List without throwing type error', () {
      final dynamic list = ['item1', 'item2'];
      final map = JsonHelpers.toMap(list);
      expect(map, isEmpty);
    });

    test('toList handles Map with data key without throwing type error', () {
      final dynamic wrapped = {
        'data': [{'id': '1', 'name': 'Item'}]
      };
      final list = JsonHelpers.toList(wrapped);
      expect(list.length, equals(1));
    });

    test('toDouble handles strings, commas, spaces and null', () {
      expect(JsonHelpers.toDouble(null), equals(0.0));
      expect(JsonHelpers.toDouble(' 12 500,50 '), equals(12500.5));
      expect(JsonHelpers.toDouble(42), equals(42.0));
    });

    test('DealModel parses flat or populated relations without crashing', () {
      final jsonWithStringRelation = {
        'id': 'deal-1',
        'title': 'Поставка оборудования',
        'customer': 'ООО Ромашка', // String instead of object!
        'amount': '1500000',
        'status': 'won',
        'comments': [],
      };
      final deal = DealModel.fromJson(jsonWithStringRelation);
      expect(deal.customerName, equals('ООО Ромашка'));
      expect(deal.amount, equals(1500000.0));
    });

    test('TaskModel parses flat or populated relations without crashing', () {
      final jsonWithStringRelation = {
        'id': 'task-1',
        'title': 'Подготовить отчёт',
        'assignedTo': 'Сардор Рахимов', // String instead of object!
        'createdBy': 'Тимур Алиев',
        'progress': '75',
      };
      final task = TaskModel.fromJson(jsonWithStringRelation);
      expect(task.assignedToName, equals('Сардор Рахимов'));
      expect(task.createdByName, equals('Тимур Алиев'));
      expect(task.progress, equals(0.75));
    });

    test('TransactionModel parses flat or populated relations without crashing', () {
      final jsonWithStringRelation = {
        'id': 'tx-1',
        'amount': '500000',
        'customer': 'ООО Вектор',
        'supplier': 'Завод Металл',
      };
      final debt = DebtModel.fromJson(jsonWithStringRelation);
      expect(debt.customerName, equals('ООО Вектор'));
      expect(debt.supplierName, equals('Завод Металл'));
      expect(debt.amount, equals(500000.0));
    });
  });
}
