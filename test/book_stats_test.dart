/// book_stats_test.dart — 统计逻辑的单元测试
library;

import 'package:lecture4/book.dart';
import 'package:lecture4/book_stats.dart';
import 'package:test/test.dart';

/// 固定测试数据：与演示数据分开，改动演示数据不会牵连测试
List<Book> sample() => const [
  Book(id: 'A', title: '书甲', category: '文学', borrowCount: 100),
  Book(id: 'B', title: '书乙', category: '文学', borrowCount: 50),
  Book(id: 'C', title: '书丙', category: '科学', borrowCount: 80),
  Book(id: 'D', title: '书丁', category: '科学', borrowCount: 20),
  Book(id: 'E', title: '书戊', category: '历史', borrowCount: 0),
];

void main() {
  group('BookStats 基本统计', () {
    test('总数 / 总借阅次数 / 平均次数', () {
      final stats = BookStats(sample());

      expect(stats.total, 5);
      expect(stats.totalBorrowCount, 250); // 100+50+80+20+0
      expect(stats.averageBorrowCount, 50.0); // 250/5
    });

    test('空列表不抛异常，平均值为 0', () {
      final stats = BookStats(const []);

      expect(stats.total, 0);
      expect(stats.totalBorrowCount, 0);
      expect(stats.averageBorrowCount, 0);
      expect(stats.countByCategory, isEmpty);
      expect(stats.topBorrowed(), isEmpty);
    });

    test('平均值四舍五入保留两位', () {
      final stats = BookStats(const [
        Book(id: 'A', title: 'T', category: 'C', borrowCount: 1),
        Book(id: 'B', title: 'T', category: 'C', borrowCount: 1),
        Book(id: 'C', title: 'T', category: 'C', borrowCount: 1),
      ]);

      expect(stats.averageBorrowCount, 1.0);

      final stats2 = BookStats(const [
        Book(id: 'A', title: 'T', category: 'C', borrowCount: 1),
        Book(id: 'B', title: 'T', category: 'C', borrowCount: 1),
        Book(id: 'C', title: 'T', category: 'C', borrowCount: 2),
      ]);
      // 4/3 = 1.333... → 1.33
      expect(stats2.averageBorrowCount, 1.33);
    });
  });

  group('分类统计', () {
    test('各类目数量正确', () {
      final stats = BookStats(sample());
      final byCategory = stats.countByCategory;

      expect(byCategory['文学'], 2);
      expect(byCategory['科学'], 2);
      expect(byCategory['历史'], 1);
      expect(byCategory.length, 3);
    });

    test('按数量降序排列，数量相同按类目名的 Unicode 码点升序', () {
      final stats = BookStats(sample());
      // 文学、科学都是 2 个，按码点比较："文"(U+6587) < "科"(U+79D1)
      // 注意这不是拼音序，只是"确定且稳定"的序——目的是让输出可复现
      expect(stats.countByCategory.keys.toList(), ['文学', '科学', '历史']);
    });

    test('分类数量之和等于总数', () {
      final stats = BookStats(sample());
      final sum = stats.countByCategory.values.fold<int>(0, (a, b) => a + b);

      expect(sum, stats.total);
    });
  });

  group('Top 排行', () {
    test('默认取前 3 名，按借阅量降序', () {
      final stats = BookStats(sample());
      final top = stats.topBorrowed();

      expect(top.length, 3);
      expect(top.map((b) => b.title).toList(), ['书甲', '书丙', '书乙']);
      expect(top.map((b) => b.borrowCount).toList(), [100, 80, 50]);
    });

    test('可以指定取前 n 名', () {
      final stats = BookStats(sample());

      expect(stats.topBorrowed(1).single.title, '书甲');
      expect(stats.topBorrowed(2).length, 2);
      expect(stats.topBorrowed(99).length, 5); // n 超过总数时返回全部
    });

    test('借阅量相同时按 id 升序，保证结果稳定', () {
      final stats = BookStats(const [
        Book(id: 'Z', title: '后', category: 'C', borrowCount: 10),
        Book(id: 'A', title: '前', category: 'C', borrowCount: 10),
      ]);

      // 两次调用结果必须一样，不能因为排序不稳定而变来变去
      expect(stats.topBorrowed(2).map((b) => b.id).toList(), ['A', 'Z']);
      expect(stats.topBorrowed(2).map((b) => b.id).toList(), ['A', 'Z']);
    });

    test('排序不修改内部列表顺序', () {
      final stats = BookStats(sample());
      final before = stats.books.map((b) => b.id).toList();

      stats.topBorrowed();

      expect(stats.books.map((b) => b.id).toList(), before);
    });

    test('内部列表不可被外部修改', () {
      final stats = BookStats(sample());

      expect(
        () => stats.books.add(
          const Book(id: 'X', title: 'T', category: 'C', borrowCount: 0),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('报告文本', () {
    test('包含关键统计信息', () {
      final report = BookStats(sample()).report();

      expect(report, contains('图书总数：5 种'));
      expect(report, contains('借阅总次数：250 次'));
      expect(report, contains('平均借阅次数：50.0 次/种'));
      expect(report, contains('文学：2 种'));
      expect(report, contains('《书甲》'));
    });

    test('空数据也能生成报告，不抛异常', () {
      final report = BookStats(const []).report();

      expect(report, contains('图书总数：0 种'));
    });
  });
}
