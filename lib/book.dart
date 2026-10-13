/// book.dart — Book 模型类：JSON ↔ 对象的双向转换
///
/// 对应实践指南四 4.2 节（JSON 与模型类）与课堂案例 async_json 步骤二。
library;

/// 图书借阅记录
class Book {
  /// 书号
  final String id;

  /// 书名
  final String title;

  /// 类目
  final String category;

  /// 借阅次数
  final int borrowCount;

  const Book({
    required this.id,
    required this.title,
    required this.category,
    required this.borrowCount,
  });

  /// 从 JSON 对象构造
  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        category: j['category'] as String,
        // 先 as num 再 toInt()：JSON 里的数字可能是 int 也可能是 double，
        // 直接 as int 遇到 12.0 会抛类型错误
        borrowCount: (j['borrowCount'] as num).toInt(),
      );

  /// 转回 JSON 对象
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'borrowCount': borrowCount,
      };

  @override
  String toString() => 'Book($id, $title, $category, $borrowCount)';
}
