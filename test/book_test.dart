/// book_test.dart — Book 模型与解析的单元测试
///
/// 覆盖：正常解析、字段缺失、类型错误、JSON 语法错误、roundtrip 一致性。
library;

import 'dart:convert';

import 'package:lecture4/book.dart';
import 'package:lecture4/book_repository.dart';
import 'package:test/test.dart';

void main() {
  group('Book.fromJson 正常路径', () {
    test('四个字段全部正确读出', () {
      final book = Book.fromJson({
        'id': 'B001',
        'title': '活着',
        'category': '文学',
        'borrowCount': 178,
      });

      expect(book.id, 'B001');
      expect(book.title, '活着');
      expect(book.category, '文学');
      expect(book.borrowCount, 178);
    });

    test('borrowCount 是 double 时也能转成 int', () {
      final book = Book.fromJson({
        'id': 'B001',
        'title': '活着',
        'category': '文学',
        'borrowCount': 12.0,
      });

      expect(book.borrowCount, 12);
      expect(book.borrowCount, isA<int>());
    });

    test('borrowCount 是小数时截断取整', () {
      final book = Book.fromJson({
        'id': 'B001',
        'title': '活着',
        'category': '文学',
        'borrowCount': 12.9,
      });

      expect(book.borrowCount, 12);
    });

    test('borrowCount 缺失时默认 0（不算错误）', () {
      final book = Book.fromJson({
        'id': 'B001',
        'title': '活着',
        'category': '文学',
      });

      expect(book.borrowCount, 0);
    });

    test('borrowCount 显式为 null 时也默认 0', () {
      final book = Book.fromJson({
        'id': 'B001',
        'title': '活着',
        'category': '文学',
        'borrowCount': null,
      });

      expect(book.borrowCount, 0);
    });
  });

  group('Book.fromJson 异常路径', () {
    test('缺少必填字段 id → BookParseException', () {
      expect(
        () => Book.fromJson({'title': 'T', 'category': 'C', 'borrowCount': 1}, index: 0),
        throwsA(isA<BookParseException>()
            .having((e) => e.field, 'field', 'id')
            .having((e) => e.message, 'message', contains('第 1 条'))),
      );
    });

    test('缺少必填字段 title → 提示里带字段名', () {
      expect(
        () => Book.fromJson({'id': 'A', 'category': 'C', 'borrowCount': 1}),
        throwsA(isA<BookParseException>()
            .having((e) => e.message, 'message', contains('title'))),
      );
    });

    test('必填字段是空字符串 → 报错', () {
      expect(
        () => Book.fromJson({'id': 'A', 'title': '  ', 'category': 'C', 'borrowCount': 1}),
        throwsA(isA<BookParseException>()
            .having((e) => e.message, 'message', contains('空字符串'))),
      );
    });

    test('id 类型不对（int）→ 提示实际类型', () {
      expect(
        () => Book.fromJson({'id': 1001, 'title': 'T', 'category': 'C', 'borrowCount': 1}),
        throwsA(isA<BookParseException>()
            .having((e) => e.message, 'message', contains('int'))),
      );
    });

    test('borrowCount 类型不对（String）→ 报错而不是静默当 0', () {
      expect(
        () => Book.fromJson(
            {'id': 'A', 'title': 'T', 'category': 'C', 'borrowCount': '很多'}),
        throwsA(isA<BookParseException>()
            .having((e) => e.field, 'field', 'borrowCount')),
      );
    });

    test('异常信息不问 index 时不含"第 N 条"', () {
      expect(
        () => Book.fromJson({'title': 'T', 'category': 'C'}),
        throwsA(isA<BookParseException>()
            .having((e) => e.message, 'message', isNot(contains('第')))),
      );
    });
  });

  group('Book.toJson', () {
    test('输出恰好四个字段', () {
      const book = Book(id: 'A', title: 'T', category: 'C', borrowCount: 7);
      final json = book.toJson();

      expect(json.keys.toSet(), {'id', 'title', 'category', 'borrowCount'});
      expect(json['borrowCount'], 7);
    });

    test('roundtrip：对象 → JSON → 对象，字段全部一致', () {
      const original = Book(id: 'B006', title: '活着', category: '文学', borrowCount: 178);
      final restored = Book.fromJson(jsonDecode(jsonEncode(original.toJson())));

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.category, original.category);
      expect(restored.borrowCount, original.borrowCount);
    });

    test('roundtrip 能保住引号、反斜杠、换行等特殊字符', () {
      const original = Book(
        id: 'E1',
        title: '带"引号"和\\反斜杠\n还有换行',
        category: '测试',
        borrowCount: 1,
      );
      final restored = Book.fromJson(jsonDecode(jsonEncode(original.toJson())));

      expect(restored.title, original.title);
    });
  });

  group('parseBooks', () {
    test('正常数组解析出正确条数', () {
      final books = parseBooks('''
        [
          {"id":"A","title":"书一","category":"文学","borrowCount":3},
          {"id":"B","title":"书二","category":"科学","borrowCount":5}
        ]
      ''');

      expect(books.length, 2);
      expect(books[0].title, '书一');
      expect(books[1].borrowCount, 5);
    });

    test('空数组解析为 0 条，不报错', () {
      expect(parseBooks('[]'), isEmpty);
    });

    test('JSON 语法错误 → DataFileException(malformedJson)', () {
      expect(
        () => parseBooks('[{"id":"A","title":"T"'),
        throwsA(isA<DataFileException>()
            .having((e) => e.problem, 'problem', DataFileProblem.malformedJson)),
      );
    });

    test('顶层不是数组 → DataFileException(notAList)', () {
      expect(
        () => parseBooks('{"id":"A"}'),
        throwsA(isA<DataFileException>()
            .having((e) => e.problem, 'problem', DataFileProblem.notAList)),
      );
    });

    test('数组里混入非对象 → 报出是第几条', () {
      expect(
        () => parseBooks('[{"id":"A","title":"T","category":"C"}, "我不是对象"]'),
        throwsA(isA<BookParseException>()
            .having((e) => e.index, 'index', 1)),
      );
    });

    test('第二条记录出错时 index 是 1（从 0 开始）', () {
      expect(
        () => parseBooks('''
          [
            {"id":"A","title":"T","category":"C","borrowCount":1},
            {"id":"B","category":"C","borrowCount":1}
          ]
        '''),
        throwsA(isA<BookParseException>()
            .having((e) => e.index, 'index', 1)
            .having((e) => e.message, 'message', contains('第 2 条'))),
      );
    });
  });

  group('loadBooks 异步读取', () {
    test('文件不存在 → DataFileException(missing) 且提示含路径', () async {
      await expectLater(
        loadBooks(path: 'data/肯定不存在的文件.json'),
        throwsA(isA<DataFileException>()
            .having((e) => e.problem, 'problem', DataFileProblem.missing)
            .having((e) => e.message, 'message', contains('数据文件缺失'))),
      );
    });

    test('读取真实数据文件成功', () async {
      final books = await loadBooks();
      expect(books, isNotEmpty);
      expect(books.first.id, isNotEmpty);
    });
  });
}
