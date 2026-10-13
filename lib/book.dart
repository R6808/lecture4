/// book.dart — Book 模型类：JSON ↔ 对象的双向转换
///
/// 对应实践指南四 4.2 节（JSON 与模型类）与课堂案例 async_json 步骤二。
///
/// 设计要点：
/// - 四个字段全部 final，对象一旦建好就不再变（配合 const 构造）
/// - fromJson 是唯一入口，内部对"字段缺失"和"类型不对"分别给出可读报错
/// - toJson 与 fromJson 严格对称，支持 roundtrip 校验
library;

/// 单条记录解析失败
///
/// 按指南第三章的"红线"要求：对外提供结果的程序不允许裸抛。
/// 这里把底层的 TypeError / 空值问题包装成一条人能看懂的信息，
/// 并且带上出错位置（第几条记录、哪个字段），方便直接定位数据问题。
class BookParseException implements Exception {
  /// 出错记录在数组里的下标（从 0 开始）；不在数组中时为 -1
  final int index;

  /// 出错的字段名
  final String field;

  /// 人能看懂的原因说明
  final String detail;

  const BookParseException({
    required this.index,
    required this.field,
    required this.detail,
  });

  /// 面向用户的提示文本
  String get message {
    final where = index >= 0
        ? '第 ${index + 1} 条记录的 "$field" 字段'
        : '"$field" 字段';
    return '数据格式有误：$where$detail';
  }

  @override
  String toString() => message;
}

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
  ///
  /// [index] 用于报错时指出是第几条记录，直接调用时可省略。
  factory Book.fromJson(Map<String, dynamic> json, {int index = -1}) {
    return Book(
      id: _requireString(json, 'id', index),
      title: _requireString(json, 'title', index),
      category: _requireString(json, 'category', index),
      // borrowCount 允许缺失，缺了就按 0 次借阅算（见下面 _optionalInt 的说明）
      borrowCount: _optionalInt(json, 'borrowCount', index),
    );
  }

  /// 取出必填的字符串字段，缺失或类型不对都抛出可读异常
  static String _requireString(
    Map<String, dynamic> json,
    String field,
    int index,
  ) {
    if (!json.containsKey(field)) {
      throw BookParseException(
        index: index,
        field: field,
        detail: '缺失，该字段为必填项',
      );
    }
    final value = json[field];
    if (value is! String) {
      throw BookParseException(
        index: index,
        field: field,
        detail: '应为字符串，实际拿到 ${value.runtimeType}（值：$value）',
      );
    }
    if (value.trim().isEmpty) {
      throw BookParseException(index: index, field: field, detail: '不能是空字符串');
    }
    return value;
  }

  /// 取出可选的整数字段，缺失时返回 0
  ///
  /// 为什么缺失不报错：一条借阅记录暂时没有统计到借阅次数是合理的业务情况，
  /// 按"借过 0 次"处理比整份数据都读不进来更合适。
  ///
  /// 但"类型不对"必须报错：字段存在却是 "abc" 这种，说明数据源出了真问题，
  /// 悄悄当成 0 会把错误藏起来，后面统计出来的数字全是错的。
  static int _optionalInt(Map<String, dynamic> json, String field, int index) {
    final value = json[field];
    if (value == null) return 0;
    if (value is! num) {
      throw BookParseException(
        index: index,
        field: field,
        detail: '应为数字，实际拿到 ${value.runtimeType}（值：$value）',
      );
    }
    // JSON 里的整数可能是 int 也可能是 double（比如 12 和 12.0），
    // 先当 num 接住再 toInt()，两条路都走得通。
    return value.toInt();
  }

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
