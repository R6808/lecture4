/// book_stats.dart — 统计与报告
///
/// 对应课堂案例 async_json 步骤二：输出总数、各类目数量、借阅量 Top3。
/// 统计部分继续沿用上一课的"集合链式方法"风格，不写手写循环。
library;

import 'book.dart';

/// 借阅数据统计
class BookStats {
  /// 参与统计的图书列表（构造时复制一份，避免外部改动影响结果）
  final List<Book> books;

  BookStats(List<Book> input) : books = List.unmodifiable(input);

  /// 图书总数
  int get total => books.length;

  /// 借阅总次数
  int get totalBorrowCount =>
      books.fold<int>(0, (sum, b) => sum + b.borrowCount);

  /// 平均借阅次数（保留两位小数；空列表返回 0，不做除零）
  double get averageBorrowCount {
    if (books.isEmpty) return 0;
    final avg = totalBorrowCount / books.length;
    return double.parse(avg.toStringAsFixed(2));
  }

  /// 各类目的图书数量
  ///
  /// 返回的 Map 按"数量从多到少、数量相同按类目名"排好序，
  /// 这样打印出来的顺序是稳定的（Map 本身的遍历顺序不该被依赖）。
  ///
  /// 关于"按类目名"：用的是 String.compareTo，也就是 **Unicode 码点序**，
  /// 不是拼音序也不是笔画序（例如"文学"(U+6587) 会排在"科学"(U+79D1) 前面）。
  /// 这里要的只是"确定且可复现"，不追求符合中文习惯的排序。
  Map<String, int> get countByCategory {
    final counted = books.fold(<String, int>{}, (map, b) {
      map[b.category] = (map[b.category] ?? 0) + 1;
      return map;
    });
    final sortedKeys = counted.keys.toList()
      ..sort((a, b) {
        final byCount = counted[b]!.compareTo(counted[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return {for (final k in sortedKeys) k: counted[k]!};
  }

  /// 借阅量最高的前 [n] 本
  ///
  /// `[...books]` 先复制再排序：内部列表是 unmodifiable 的，
  /// 直接 sort 会抛 UnsupportedError，而且也会破坏原顺序。
  List<Book> topBorrowed([int n = 3]) {
    final sorted = [...books]..sort((a, b) {
        final byCount = b.borrowCount.compareTo(a.borrowCount);
        return byCount != 0 ? byCount : a.id.compareTo(b.id);
      });
    return sorted.take(n).toList();
  }

  /// 生成完整报告文本
  String report() {
    final buffer = StringBuffer();
    buffer.writeln('图书借阅数据汇总');
    buffer.writeln('─' * 34);
    buffer.writeln('图书总数：$total 种');
    buffer.writeln('借阅总次数：$totalBorrowCount 次');
    buffer.writeln('平均借阅次数：$averageBorrowCount 次/种');

    buffer.writeln('各类目数量：');
    countByCategory.forEach((category, count) {
      buffer.writeln('  $category：$count 种');
    });

    buffer.writeln('借阅量 Top3：');
    final top = topBorrowed();
    for (var i = 0; i < top.length; i++) {
      final b = top[i];
      buffer.writeln('  ${i + 1}. 《${b.title}》 ${b.borrowCount} 次（${b.category}）');
    }
    return buffer.toString().trimRight();
  }
}
