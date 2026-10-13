/// 独立研究一：Stream 与 Future 链对比
///
/// 研究问题：同样要"隔一段时间产出一个值"，Stream 和 Future 链有什么本质区别？
///
/// 结论先说：
/// - **Future 是"一次性的"**：一个 Future 只代表一个将来会有的值。
///   想产出多个值，只能把 Future 串起来（`then` 套 `then`），
///   而每次 `then` 都会产生一个**新的** Future，最后你只拿到链尾那一个。
/// - **Stream 是"0 到多个值的时间序列"**：它本身就是一条通道，
///   `await for` 可以边到边处理，不必等全部到齐。
/// - 所以指南说"Future 是一次性的 Stream"是很准确的：
///   Future 相当于 `Stream` 里只有一个元素、且马上关闭的那种特殊情况。
///
/// 运行：dart run research/stream_vs_future.dart
library;

/// 用 Stream 产出 3 个值，每个间隔 [gap]
Stream<int> numbersAsStream(int count, Duration gap) async* {
  for (var i = 1; i <= count; i++) {
    await Future<void>.delayed(gap);
    yield i * 10;
  }
}

/// 用 Future 链产出 3 个值，每个间隔 [gap]
///
/// 注意返回值类型：只能返回链尾的那个 int，前面两个值在链里被吃掉了。
/// 想让调用方看到全部，就只能再往回调里塞一个回调——又回到了回调风格。
Future<int> lastNumberAsFutureChain(int count, Duration gap) async {
  var last = 0;
  for (var i = 1; i <= count; i++) {
    last = await Future<int>.delayed(gap, () => i * 10);
  }
  return last;
}

/// 记录"第几个值是在第几毫秒到达的"
Future<List<int>> consumeStream(Stream<int> stream, Stopwatch sw) async {
  final arrivals = <int>[];
  // await for：每来一个值就处理一个，不必等流关闭
  await for (final value in stream) {
    arrivals.add(sw.elapsedMilliseconds);
    print('   收到值 $value（第 ${sw.elapsedMilliseconds} ms）');
  }
  return arrivals;
}

Future<void> main() async {
  print('==================================================');
  print(' 独立研究一：Stream 与 Future 链对比');
  print('==================================================\n');

  const gap = Duration(milliseconds: 300);
  const count = 3;

  // ---------- 实验一：Stream 逐值到达 ----------
  print('===== 实验一：Stream —— 值随时间逐个到达 =====');
  var sw = Stopwatch()..start();
  print('  await for (final v in stream) 开始消费：');
  final streamArrivals = await consumeStream(numbersAsStream(count, gap), sw);
  sw.stop();
  print('  流关闭，总耗时 ${sw.elapsedMilliseconds} ms');
  print('  结论：每个值一到就能立刻处理，全程 3 个值分别在 '
      '${streamArrivals.join(" / ")} ms 到达。');

  // ---------- 实验二：Future 链只有链尾 ----------
  print('\n===== 实验二：Future 链 —— 中间值拿不到 =====');
  sw = Stopwatch()..start();
  print('  调用 lastNumberAsFutureChain，等待中……');
  final last = await lastNumberAsFutureChain(count, gap);
  sw.stop();
  print('  拿到最后一个值：$last，总耗时 ${sw.elapsedMilliseconds} ms');
  print('  结论：耗时一样（都是 ${count * 300} ms 左右），');
  print('        但中间那两个值（10、20）在链内部被丢掉了，调用方只看到 $last。');
  print('        想拿到全部，就必须再传一个回调进去接——这正是 Stream 要解决的问题。');

  // ---------- 实验三：把 Future 列表变成 Stream ----------
  print('\n===== 实验三：Stream.fromFutures —— 桥接两种模型 =====');
  sw = Stopwatch()..start();
  final futures = [
    Future<int>.delayed(const Duration(milliseconds: 300), () => 1),
    Future<int>.delayed(const Duration(milliseconds: 100), () => 2),
    Future<int>.delayed(const Duration(milliseconds: 200), () => 3),
  ];
  print('  三个 Future 各自的延时是 300 / 100 / 200 ms（故意不同）');
  print('  用 Stream.fromFutures 消费，按**完成先后**到达：');
  final bridged = await consumeStream(Stream<int>.fromFutures(futures), sw);
  sw.stop();
  print('  总耗时 ${sw.elapsedMilliseconds} ms');
  print('  到达顺序：${bridged.join(" / ")} ms —— 注意不是 1、2、3 的顺序，');
  print('  而是按各自完成时间排序（100ms 的 2 先到，接着 200ms 的 3，最后 300ms 的 1）。');

  // ---------- 实验四：Stream 可以被多次订阅吗 ----------
  print('\n===== 实验四：单订阅流的限制 =====');
  final single = Stream<int>.value(42);
  print('  第一次 await for：${await single.first}');
  try {
    final again = await single.first;
    print('  第二次 await for：$again');
  } catch (e) {
    print('  第二次 await for 失败：${e.runtimeType}');
    print('  $e');
  }
  print('  结论：默认的 Stream 是**单订阅流**，只能被消费一次。');
  print('        这也是它和 Future 的一个共同点——两者都只能"读一遍"。');

  // ---------- 小结 ----------
  print('\n==================================================');
  print(' 对比小结');
  print('--------------------------------------------------');
  print('  维度        │ Future              │ Stream');
  print('  值的个数    │ 恰好 1 个           │ 0 到多个');
  print('  中间结果    │ 拿不到（在链内部）  │ 每个值都能拿到');
  print('  处理时机    │ 只能等最终结果      │ 边到边处理');
  print('  能否取消    │ 不能                │ 可以（subscription.cancel）');
  print('  订阅次数    │ 读一次              │ 单订阅流读一次；广播流可多次');
  print('  典型用途    │ 一次网络请求、读文件│ 日志流、位置更新、WebSocket');
  print('==================================================');
}
