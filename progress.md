# 进度报告4（第 6 周·Dart 语言基础三：异步、异常与包管理）

- 姓名：容磊　学号：20251060108
- 仓库：https://github.com/R6808/lecture4
- 对应实践指南：《学生实践指南四　Dart 语言基础三：异步、异常与包管理》
- 对应课堂案例：`async_json`

---

## 一、任务理解

这次课是 Dart 基础部分的收官，主题是**异步、异常与包管理**。指南把内容边界说得很清楚：
服务端相关的内容已经压缩掉了，这一章保留的是**支撑移动端网络访问的最小集合**，
第 11 课会直接复用。所以我理解这次作业的重点不是"学会一个案例"，
而是**把第 11 课做网络请求必须的三样东西练熟**。

任务分三块：

1. **课堂案例复现（必做）**：复现 `async_json`——异步读取本地 JSON 数据集，
   解析成模型类，输出总数、各类目数量、借阅量 Top3。指南把它拆成三步，
   每步一次 Git 提交，而且第三步专门是"异常路径"——这说明**异常处理不是附加题，是主线**。

2. **自主实践基本要求（必做）**：五件事——把给定的嵌套回调版改成顺序 await 版；
   文件缺失/字段缺失/类型错误三类异常全部要有可读提示；JSON 完整字段模型化
   并用 toJson 做反向验证（roundtrip 一致）；pubspec 依赖用 `^` 约束且无冗余；
   最后如实标注 AI 使用方式。

3. **独立研究任务（选做）**：Stream 与 Future 链对比、`Future.wait` 并行实验、
   isolate 重计算演示。

**验收标准**（我按指南写的检查点抄下来作为自查依据）：
- 正常路径统计输出正确；
- 文件缺失路径输出友好提示、**不崩溃**；
- 能口头解释 `await` 在案例中的作用。

指南第三章还有一条"红线"我记下来了：**任何对外提供结果的程序不允许裸抛**，
网络/文件路径必须捕获并给出用户可读的提示，`finally` 负责清理，
并注明"这是阶段作业一的检查点"。

---

## 二、环境与工具

| 项目 | 内容 |
| --- | --- |
| 操作系统 | Windows（本机） |
| Dart SDK | 3.13.4 (stable) |
| 依赖 | `path: ^1.9.1`；dev: `lints: ^6.0.0`、`test: ^1.25.6` |
| 编辑器 / AI 工具 | TraeCode |
| 运行目标 | **命令行（Dart VM）**。本次作业是纯 Dart 异步与异常训练，不涉及界面，所以没有用 Web、模拟器或真机 |
| 项目创建方式 | `dart create lecture4 --template=console` |
| 仓库 | 本次单独新建仓库 `lecture4` |

---

## 三、过程记录

1. **建工程**：`dart create lecture4 --template=console`，删掉模板自带的
   `bin/lecture4.dart`、`lib/lecture4.dart`、`test/lecture4_test.dart`。
2. **步骤一·数据集与依赖**：`dart pub add path`；把数据集放到 `data/books.json`。
   → 提交 `feat: dataset & deps ready`
3. **步骤二·解析与统计**：写 `lib/book.dart`（`Book.fromJson`/`toJson`）、
   `lib/book_repository.dart`（异步读 + 解析）、`lib/book_stats.dart`（统计与报告），
   以及入口 `bin/async_json.dart`。跑通正常路径后提交。
   → 提交 `feat: parse & stats from books.json`
4. **试异常路径，发现很糟**：把数据文件指向一个不存在的路径，程序的反应是
   `Unhandled exception: PathNotFoundException: ...` 加一串调用栈（见第六节问题 1）。
   这正是指南第三步要解决的问题。
5. **步骤三·健壮性**：设计了两层异常——`DataFileException`（文件层面）和
   `BookParseException`（记录层面，带"第几条、哪个字段"）；`main` 里分类捕获并兜底。
   同时按指南的"故意实验"要求，给 `borrowCount` 加了缺失时默认 0 的处理。
   写 35 个单元测试。→ 提交 `feat: robust missing-field & file handling`
6. **自主实践 1-3**：写 `bin/callback_hell.dart`（改造前的 4 层嵌套回调版，作为对照）、
   `bin/practice_exceptions.dart`（12 个异常场景演示）、
   `bin/practice_roundtrip.dart`（四轮 roundtrip 验证）。
   → 提交 `feat: 自主实践任务 1-3`
7. **独立研究**：`research/` 下三个模块，全部实测记录数据。
   → 提交 `feat: 独立研究任务`
8. **格式统一**：`dart format`，10 个文件被规整，复检 0 changed。
   → 提交 `style: dart format 统一代码格式`
9. **补文档与证据**：写 `README.md`、本报告，把真实输出渲染成 `images/` 下的截图。

**关于依赖的一次实测**：指南 4.1 节写"本课案例用到 path 与 path_provider"，
我按字面加了 `path_provider`，结果**整个工程编译不过**（287 条错误），
原因是它是 Flutter 插件。按"无冗余依赖"要求移除了，详见第六节问题 2。

---

## 四、关键代码

### 4.1 案例主入口：async/await（自主实践任务 1 的"改造后"）

`bin/async_json.dart`：

```dart
Future<void> main(List<String> args) async {
  final path = args.isNotEmpty ? args.first : defaultDataPath;

  print('=== async_json：异步读取并汇总图书借阅数据 ===');
  print('数据文件：$path');
  print('');

  final stopwatch = Stopwatch()..start();

  try {
    // await 在这里的作用：把控制权交还事件循环，等磁盘读完再继续。
    final books = await loadBooks(path: path);
    final stats = BookStats(books);

    print(stats.report());

    stopwatch.stop();
    print('');
    print('读取并统计完成：${books.length} 条记录，耗时 ${stopwatch.elapsedMilliseconds} ms');
  } on DataFileException catch (e) {
    // 文件层面的问题：给出人能看懂的提示，不打印堆栈
    print('读取失败：${e.message}');
    exitCode = 1;
  } on BookParseException catch (e) {
    // 数据格式层面的问题：已经带上了"第几条、哪个字段"
    print('解析失败：${e.message}');
    exitCode = 1;
  } catch (e) {
    // 兜底：按指南要求，任何对外提供结果的程序都不允许裸抛
    print('发生未知错误：$e');
    exitCode = 1;
  }
}
```

逐行解释：

- `Future<void> main(...) async`：把 `main` 声明成异步函数。**Dart 会等这个 Future 完成才退出进程**，
  这一点很关键——如果 `main` 不是 async、异步任务又没被 await，程序可能在结果出来之前就结束了
  （指南 2.1 节专门警告过这个坑）。
- `await loadBooks(path: path)`：`await` 的语义是"**等结果，但把控制权交还事件循环**"。
  等磁盘的这段时间，事件循环可以去做别的事。这正是它和"同步阻塞"的根本区别，
  也是检查点里"能口头解释 await 的作用"要考的点。
- 三个 `catch` 是**分层**的：`on DataFileException` 处理文件问题、
  `on BookParseException` 处理数据格式问题、最后的 `catch (e)` 兜底。
  顺序不能颠倒（`on` 子句要写在通用 `catch` 前面）。
- `exitCode = 1`：命令行程序的退出码。成功是 0，失败是 1，
  这样别人写脚本调用时能判断成败。**注意这里不是 `exit(1)`**——
  `exit()` 会立刻终止进程，可能来不及把输出刷出去。

AI 标注：由 AI 辅助生成初稿，我逐行核对了 `await` 的语义与异常捕获顺序，
并补了退出码处理。验证方式见第五节的两条路径实测。

### 4.2 模型类与可读异常（自主实践任务 2、3）

`lib/book.dart` 的核心部分：

```dart
factory Book.fromJson(Map<String, dynamic> json, {int index = -1}) {
  return Book(
    id: _requireString(json, 'id', index),
    title: _requireString(json, 'title', index),
    category: _requireString(json, 'category', index),
    // borrowCount 允许缺失，缺了就按 0 次借阅算
    borrowCount: _optionalInt(json, 'borrowCount', index),
  );
}

static String _requireString(Map<String, dynamic> json, String field, int index) {
  if (!json.containsKey(field)) {
    throw BookParseException(index: index, field: field, detail: '缺失，该字段为必填项');
  }
  final value = json[field];
  if (value is! String) {
    throw BookParseException(
      index: index, field: field,
      detail: '应为字符串，实际拿到 ${value.runtimeType}（值：$value）',
    );
  }
  if (value.trim().isEmpty) {
    throw BookParseException(index: index, field: field, detail: '不能是空字符串');
  }
  return value;
}

static int _optionalInt(Map<String, dynamic> json, String field, int index) {
  final value = json[field];
  if (value == null) return 0;               // 缺失 → 默认 0
  if (value is! num) {                       // 类型不对 → 报错
    throw BookParseException(
      index: index, field: field,
      detail: '应为数字，实际拿到 ${value.runtimeType}（值：$value）',
    );
  }
  return value.toInt();                      // int 和 double 都走得通
}
```

逐行解释与设计取舍：

- **`_requireString` 与 `_optionalInt` 的区别是本题的核心设计判断**：
  前者缺了就报错，后者缺了默认 0。判断依据不是"好不好处理"，
  而是"**这个字段缺了，数据还有没有意义**"——
  一条借阅记录暂时没统计到次数是合理的业务情况，按 0 次算比让整份数据都读不进来更合适；
  但书号、书名、类目缺了这条记录就没有意义，必须报错。
- **类型不对时 `borrowCount` 必须报错而不是当 0**：字段存在却是 `"很多"` 这种，
  说明数据源出了真问题。悄悄当成 0 会把错误藏起来，后面统计出来的数字全是错的。
  这是"宽容"和"掩盖错误"的分界线。
- **`(value as num).toInt()` 而不是 `as int`**：JSON 里的整数可能是 `int` 也可能是 `double`
  （`12` 和 `12.0` 都合法）。先当 `num` 接住再 `toInt()`，两条路都走得通。
  这正是指南 4.2 节"翻车警告"强调的写法。
- **`index` 参数的作用**：报错时能说出是第几条记录。
  默认值 `-1` 表示"不在数组里"，此时提示文本会省略"第 N 条"。

AI 标注：由 AI 辅助生成初稿。**"哪些字段缺失该报错、哪些该给默认值"这个划分是我自己定的**，
依据是上面那条业务判断；AI 最初给的版本对所有缺失字段一律报错，
我改成现在这样是因为指南的"故意实验"明确要求 `borrowCount` 缺失要有默认值处理。
验证方式：`bin/practice_exceptions.dart` 的 12 个场景 + `test/book_test.dart` 的 12 条用例。

### 4.3 回调版 vs await 版（自主实践任务 1 的对照）

改造前的嵌套回调版（`bin/callback_hell.dart`）关键结构：

```dart
void loadBooksWithCallbacks({
  required String path,
  required void Function(List<Book> books) onSuccess,
  required void Function(String message) onError,
}) {
  File(path).exists().then((exists) {              // 第 1 层
    if (!exists) { onError('数据文件缺失，请检查 $path'); return; }
    File(path).readAsString().then((text) {        // 第 2 层
      // …… 解析 ……（第 3 层）
      onSuccess(books);                            // 第 4 层
    }, onError: (Object e) => onError('文件读取出错：$e'));
  }, onError: (Object e) => onError('检查文件时出错：$e'));
}
```

对照来看，回调风格有三个具体的麻烦：

1. **函数不返回结果也不抛异常**：结果和错误都靠传进来的两个回调"送出去"，
   函数签名因此变成 `void`，调用方看签名完全不知道它会产出什么。
2. **错误要在每一层重新接一次**：上面那两个 `onError:` 参数必须写两遍，
   漏一层异常就静默丢失。
3. **控制流是倒着读的**：业务的先后顺序（先查文件、再读、再解析）
   被 `then` 的嵌套结构打散了。

改成 await 版之后，这三条全部消失：函数 `return List<Book>`、`throw` 异常，
错误只需要在最外层 catch 一次，代码从上到下就是执行顺序。
**两个版本的输出逐字符一致**（实测见第八节图 04/05），所以这个改写是纯粹的可读性提升。

AI 标注：回调版是我按"典型的嵌套回调写法"构造的，用来做前后对照
（原题附的版本我手上没有，这一点在第七节说明了）。验证方式是两个程序跑同一批输入、比对输出。

---

## 五、检查点结果

### 检查点 1：正常路径统计输出正确

命令 `dart run bin/async_json.dart`，实测输出：

```
图书总数：18 种
借阅总次数：1646 次
平均借阅次数：91.44 次/种
各类目数量：
  计算机：4 种    文学：3 种    科学：3 种    历史：2 种
  哲学：2 种      经济：2 种    数学：1 种    艺术：1 种
借阅量 Top3：
  1. 《活着》 178 次（文学）
  2. 《深入理解计算机系统》 156 次（计算机）
  3. 《算法导论》 143 次（计算机）
```

**手算核对**（不是我只看程序跑通了就算）：

- 总数：数据集 18 条 → 18 ✓
- 借阅总次数：156+98+143+87 = 484（计算机）；132+178+95 = 405（文学）；
  76+64 = 140（历史）；121+58+43 = 222（科学）；51+109 = 160（经济）；
  39（艺术）；83+47 = 130（哲学）；66（数学）。
  合计 484+405+140+222+160+39+130+66 = **1646** ✓
- 平均：1646 ÷ 18 = 91.444… → 保留两位 **91.44** ✓
- 各类目数量之和：4+3+3+2+2+2+1+1 = 18 = 总数 ✓
- Top3：全部 18 个借阅量排序后前三是 178、156、143，对应《活着》《深入理解计算机系统》《算法导论》 ✓

这些数字同时写进了单元测试做断言，以后改代码一旦算错，测试会立刻红。

### 检查点 2：文件缺失路径输出友好提示、不崩溃

命令 `dart run bin/async_json.dart data/不存在的文件.json`，实测输出：

```
=== async_json：异步读取并汇总图书借阅数据 ===
数据文件：data\不存在的文件.json

读取失败：数据文件缺失，请检查 data\不存在的文件.json
```

退出码 1，**没有堆栈、没有 Unhandled exception**。
对比"改造前"的表现（第六节问题 1）差别很明显。

### 其他验证

| 项 | 命令 | 结果 |
| --- | --- | --- |
| 静态检查 | `dart analyze` | `No issues found!` |
| 单元测试 | `dart test` | `All tests passed!`（35 个用例） |
| 格式规范 | `dart format --set-exit-if-changed` | `Formatted 12 files (0 changed)` |
| Git 规范 | `git log --oneline` | 6 次提交，前三次与指南给的提交信息完全一致 |

---

## 六、问题与调试

### 问题 1（异步场景的真实报错）：裸抛的 `PathNotFoundException`

**现象**：步骤二做完后，我把数据文件指向一个不存在的路径试异常路径，程序的反应是：

```
Unhandled exception:
PathNotFoundException: Cannot open file, path = 'data\nope.json'
  (OS Error: 系统找不到指定的文件。, errno = 2)
#0      _checkForErrorResponse (dart:io/common.dart:58:9)
#1      _File.open.<anonymous closure> (dart:io/file_impl.dart:438:7)
<asynchronous suspension>
```

**定位过程**：这个报错本身很好懂，但它暴露了一个设计问题——
堆栈是给**开发者**看的，不是给**用户**看的。
用户看到 `errno = 2` 和 `<asynchronous suspension>` 完全不知道该怎么办；
而且 `Unhandled exception` 意味着程序是**崩溃退出**的，不是"友好地告诉你出错然后正常结束"。

另外一个细节值得记：堆栈里那行 `<asynchronous suspension>`。
这是 Dart 异步调试的一个特点——`await` 会让调用栈"断开"，
所以异步代码的堆栈不像同步代码那样完整。这也是为什么
**异步代码里给出可读的错误信息比同步代码更重要**：
堆栈本来就不好读，再让它裸奔就更没法查了。

**解决方案**：按指南第三章的要求做了两层异常，并在 `main` 里分类捕获：
文件层面抛 `DataFileException`（带 `problem` 枚举区分缺失/读不了/JSON 语法错/顶层非数组），
记录层面抛 `BookParseException`（带 `index` 和 `field`）。
每个异常的 `message` getter 负责拼出人话。

**验证**：`dart run bin/async_json.dart data/不存在的文件.json`
输出 `读取失败：数据文件缺失，请检查 …`，退出码 1，无堆栈。

### 问题 2：`path_provider` 让整个工程编译不过（287 条错误）

**现象**：指南 4.1 节写"本课案例用到 path 与 path_provider"，
我按字面执行 `dart pub add path_provider`，**依赖解析显示成功**：

```
+ flutter 0.0.0 from sdk flutter
+ path_provider 2.1.6
+ sky_engine 0.0.0 from sdk flutter
... 共 22 个包
Changed 22 dependencies!
```

但紧接着 `dart run` 直接爆炸，**287 条编译错误**：

```
Error: 'Offset' isn't a type.
  final Offset globalPosition;
Error: 'FlutterView' isn't a type.
  factory DeviceGestureSettings.fromView(ui.FlutterView view) {
Error: Method not found: 'clampDouble'.
```

**定位过程**：错误全部指向 `E:/flutter/packages/flutter/lib/src/...`，
也就是 Flutter SDK 自己的源码。这说明 `path_provider` 把整个 Flutter 框架
作为传递依赖拖了进来（因为它要实现"获取应用目录"，各平台实现都依赖 Flutter 引擎）。

**根因**：`path_provider` 是 **Flutter 插件**，它的能力来自平台通道
（platform channel），需要 Flutter 引擎提供 `dart:ui`（`Offset`、`FlutterView`、
`clampDouble` 等类型）。本工程是 `dart create` 出来的**纯 Dart 控制台程序**，
根本没有 Flutter 引擎。

关键点是：这**不是"运行时才报错"**，而是"依赖一旦进来，整个工程连编译都过不了"——
因为 Dart 编译时会去解析所有可达的库，包括 Flutter 的源码。

**解决方案**：移除它。`dart pub remove path_provider` 之后，
连带 22 个传递依赖一起消失（flutter、sky_engine、jni、objective_c…），
`dart analyze` 立刻恢复 `No issues found!`。

**为什么这是正确的处理**：自主实践任务 4 明确要求"无冗余依赖"。
在纯 Dart 工程里引入一个用不了、还让工程编译不过的包，正是最典型的冗余依赖。
`path_provider` 留到第 10 课做 Flutter 应用时再用。

**给我的教训**：**"依赖能装上"和"依赖能用"是两回事。**
`pub add` 只做版本求解，不检查这个包在当前工程类型（纯 Dart / Flutter）下是否可用。
以后加依赖前要先想清楚它是不是平台相关的。

### 问题 3：我自己写错的测试断言（`compareTo` 是码点序，不是拼音序）

**现象**：`test/book_stats_test.dart` 里有一条断言失败了：

```
Expected: ['科学', '文学', '历史']
  Actual: ['文学', '科学', '历史']
```

**定位过程**：一开始我以为是排序实现错了，去查 `book_stats.dart` 里的比较函数：

```dart
final sortedKeys = counted.keys.toList()
  ..sort((a, b) {
    final byCount = counted[b]!.compareTo(counted[a]!);
    return byCount != 0 ? byCount : a.compareTo(b);
  });
```

"文学"和"科学"都是 2 本，所以走到 `a.compareTo(b)`。
`String.compareTo` 比的是 **UTF-16 码点**：文 = U+6587，科 = U+79D1，
所以"文学"确实应该排在"科学"前面。

**是测试写错了，不是代码错了**——我下意识按拼音序去预期，
但实现用的是码点序。

**解决方案**：改测试断言为正确顺序，同时在实现的注释里写明
"这是 Unicode 码点序，不是拼音序"，避免以后再有人误读。

**为什么不去把它改成拼音序**：这里要的只是"**确定且可复现**"——
同一个数据集每次跑出来顺序都一样就行，不追求符合中文习惯。
真要做拼音排序得引入额外的库或维护拼音表，对这个案例是过度设计。

**教训**：写中文相关的排序断言时，别凭直觉假定顺序，
先确认比较函数用的是什么规则。

---

## 七、AI使用记录

本次使用 TraeCode 辅助。逐条记录如下（用途 / 指令摘要 / 输出 / 本人验证方式）：

| 序 | 用途 | 指令摘要 | 输出 | 本人验证方式 |
| --- | --- | --- | --- | --- |
| 1 | 生成 `Book` 模型骨架 | "按实践指南 4.2 节的 Book 示例，写模型类：四个 final 字段、const 构造、factory fromJson、toJson；数字用 `as num` 再 toInt" | `lib/book.dart` 初稿 | 对照指南 4.2 逐行核对；补了"哪类缺失该报错、哪类给默认值"的划分；用 12 条用例验证 |
| 2 | 设计异常分层 | "文件缺失、字段缺失、类型错误三类要给出可读提示，设计异常类型" | `DataFileException`（带 problem 枚举）+ `BookParseException`（带 index/field） | 用 `bin/practice_exceptions.dart` 跑 12 个场景逐个检查提示文本是否说清了"哪里错了" |
| 3 | 统计与报告 | "统计总数、各类目数量、借阅量 Top3，用集合链式方法" | `lib/book_stats.dart` 初稿 | **手算了一遍** 1646、91.44、Top3 三项与程序输出比对（见第五节）；补了空列表与并列排名的用例 |
| 4 | 构造回调版对照 | "写一个典型的 4 层嵌套回调版，功能与 await 版完全相同，用于对照" | `bin/callback_hell.dart` | 两个程序跑同一批输入、逐字符比对输出一致；人工检查错误是否每层都接了 |
| 5 | 排查 `path_provider` | 贴出 287 条编译错误 | 指出它是 Flutter 插件、依赖 `dart:ui`；建议移除 | 亲自跑 `dart pub remove` 确认 22 个包消失、`analyze` 恢复 0 告警；把错误摘要存档 |
| 6 | 排查测试失败 | 贴出 `Expected ['科学','文学','历史'] / Actual ['文学','科学','历史']` | 指出 `String.compareTo` 是 UTF-16 码点序，"文"(U+6587) < "科"(U+79D1) | 自己查了码点确认 U+6587 < U+79D1；改断言并在实现注释里写明排序规则 |
| 7 | 三个独立研究模块骨架 | "分别写 Stream/Future 对比、Future.wait 串并行计时、isolate 阻塞演示" | `research/` 下三个文件初稿 | **逐条核对官方文档**（dart.dev 的 async 与 isolates 页）；把 AI 给的结论句全部换成自己实跑后再写的数字 |

**两条需要说明的地方**：

1. **数据集是我按字段结构自建的**。指南要求 `books.json` 与课程统一数据集
   "零差异"，但我手上没有课程资源目录里的那份文件。
   我按指南 4.1 节给出的字段（`id`、`title`、`category`、`borrowCount`）
   造了 18 条数据。**程序只依赖字段名、不依赖具体内容**，
   所以拿到官方数据集后直接替换 `data/books.json` 即可，代码无需任何改动。
   第五节里的手算核验是针对当前这份数据做的，换成官方数据后数字会变，
   但核验方法一样。

2. **自主实践任务 1 的"给定的嵌套回调版"我手上也没有**（指南写"作业页附"）。
   `bin/callback_hell.dart` 是我按典型的嵌套回调写法构造的对照版本，
   用来展示"改造前"的问题。如果老师提供了原版回调代码，
   按同样的思路改写即可，方法完全一样。

**说明**：所有 AI 生成的代码都经过实跑验证，验证手段是
`dart analyze`（0 告警）+ `dart test`（35 个用例）+ `dart run` 的实测输出，
而不是只看代码"像是对的"。独立研究部分的数字全部来自本机实测
（串并行耗时、定时器触发次数、并行提速倍数），不是估算的。

---

## 八、证据截图

截图文件都在仓库 `images/` 目录下，是把命令的**真实输出**原样渲染成的终端截图。

| 图 | 文件 | 说明 |
| --- | --- | --- |
| 01 | `images/01-检查点-正常路径输出.png` | `dart run bin/async_json.dart` 的完整输出。证明检查点"正常路径统计输出正确" |
| 02 | `images/02-检查点-异常路径输出.png` | `dart run bin/async_json.dart data/不存在的文件.json`，只有一行友好提示、退出码 1。证明检查点"文件缺失路径输出友好提示不崩溃" |
| 03 | `images/03-检查点-dart-test-全部通过.png` | `dart test` 的完整输出，35 个用例逐条列出，最后 `All tests passed!` |
| 04 | `images/04-检查点-dart-analyze-无告警.png` | `dart analyze` 输出 `No issues found!`、Dart SDK 版本、`dart format` 复检 0 changed |
| 05 | `images/05-回调版与await版对照.png` | 两个版本的输出并排展示，逐行一致——证明改写没有改变行为，只是提升了可读性 |
| 06 | `images/06-问题与调试-裸异常对照.png` | 第六节问题 1 的前后对照：改造前是 `PathNotFoundException` 加堆栈，改造后是一行友好提示 |
| 07 | `images/07-问题与调试-path_provider.png` | 第六节问题 2：`pub add` 显示成功，随后 287 条编译错误，移除后恢复 0 告警 |
| 08 | `images/08-自主实践-三类异常兜底.png` | `bin/practice_exceptions.dart` 的部分输出，展示字段缺失与类型错误的具体提示文本（都带"第几条、哪个字段"） |
| 09 | `images/09-自主实践-roundtrip验证.png` | `bin/practice_roundtrip.dart` 的四轮验证结果，6 项全部通过，含"故意漏字段能被抓出来"的证明 |
| 10 | `images/10-独立研究一-Stream对比.png` | Stream 三个值分别在 313/619/930 ms 到达，而 Future 链只拿得到最后一个值 |
| 11 | `images/11-独立研究二-Future等待并行.png` | 串行 3023 ms vs 并行 1013 ms（2.98 倍）；部分失败时默认 608 ms 才报错、`eagerError` 407 ms 即返回 |
| 12 | `images/12-独立研究三-isolate对比.png` | 同步计算 827 ms 期间定时器**触发 0 次**（期望 41 次）；`Isolate.run` 同样 825 ms 触发 40 次 |
| 13 | `images/13-Git提交记录.png` | `git log --oneline --decorate` 的 6 次提交与受控文件清单，前三次提交信息与指南一致 |

图 13 的说明：截图对应生成截图时的 HEAD。前三次提交信息与
《学生实践指南四》第五部分给出的三条完全一致
（`feat: dataset & deps ready` / `feat: parse & stats from books.json` /
`feat: robust missing-field & file handling`），之后的提交分别对应自主实践、独立研究、
格式规范与文档。截图文件本身在最后一个提交中入库。

---

## 九、自评

### 对照指南 6.1 案例复现

| 项 | 要求 | 完成情况 | 自评 |
| --- | --- | --- | --- |
| 步骤一 | 准备数据与依赖 | `data/books.json`（18 条）+ `path` 依赖，按 `^` 约束 | 完成（数据集为自建，见第七节说明） |
| 步骤二 | 解析与统计 | `Book.fromJson`/`toJson`；main 异步读取；输出总数、各类目数量、Top3 | 完成 |
| 步骤三 | 异常路径 | 两层异常 + 分类捕获 + 兜底；按"故意实验"给 `borrowCount` 加了缺失默认 0 | 完成 |
| 检查点 | 正常与异常两路均正确输出 | 正常 18/1646/91.44/Top3 与手算一致；异常一行友好提示、退出码 1 | 完成 |
| Git 规范 | 每步一次提交 | 6 次提交，前三次提交信息与指南给的完全一致 | 完成 |

### 对照指南 6.2 自主实践基本要求

| 序 | 任务 | 完成情况 | 自评 |
| --- | --- | --- | --- |
| 1 | async/await 改写回调版 | `bin/callback_hell.dart` ↔ `bin/async_json.dart`，输出逐字符一致 | 完成（回调版为自建对照，见第七节） |
| 2 | 三类异常兜底 | 文件缺失 / 字段缺失 / 类型错误全部带位置信息的可读提示；12 个场景演示 | 完成 |
| 3 | JSON 模型化 + roundtrip | 四轮验证：文本↔对象、幂等性、边界字符、以及"漏字段能被抓出来" | 完成 |
| 4 | pubspec 规范 | 全部 `^` 约束；实测移除冗余依赖 `path_provider`；`pubspec.lock` 已提交 | 完成 |
| 5 | AI 使用标注 | 第七节逐条记录，并说明了两处资源缺失的替代方案 | 完成 |

### 对照指南 6.3 独立研究任务（选做）

| 序 | 任务 | 完成情况 | 自评 |
| --- | --- | --- | --- |
| 1 | Stream 与 Future 链对比 | 四个实验：逐值到达时序、Future 链丢中间值、`Stream.fromFutures` 桥接、单订阅流限制 | 完成 |
| 2 | `Future.wait` 并行实验 | 串并行计时（2.98 倍）、任务数影响、**部分失败的两种模式**、一个常见误用 | 完成 |
| 3 | isolate 重计算演示 | 用 20 ms 定时器量化事件循环阻塞（0 次 vs 40 次触发）、多 isolate 真并行（3.35 倍） | 完成 |

### 我认为还做得不够的地方

- **数据集不是课程官方那份**：虽然代码不依赖具体内容、替换即可，
  但"与统一数据集零差异"这一条严格说来没有满足。拿到官方文件后应立刻替换并重跑核验。
- **`throw` 时机的测试还能更严**：目前测的是"抛了没抛"，没有测"抛出来的 `message`
  文本是否符合预期"。提示文本是给人看的，也应该被断言保护。
- **`finally` 用得少**：指南第三章要求"`finally` 负责清理"，
  但本案例没有需要清理的资源（`File.readAsString` 内部自己会关文件流），
  所以只在讲解里提到、代码里没用上。这是合理的，但也说明我对 `finally` 还停留在"知道"层面。
- **`Stream` 只做了消费端实验**：指南 2.2 节说"本课只需会用 `await for` 消费一个流"，
  我按要求做了，但没有自己写 `StreamController` 或 `StreamTransformer`，
  对流的理解还比较浅。

---

## 十、一句话收获与下一步计划

**一句话收获**：这次最大的收获不是学会了 `async`/`await` 的语法，
而是搞清楚了 **`await` 到底做了什么**——它让出事件循环，而不是阻塞线程；
也正因为如此，异步程序的错误处理必须比同步程序更主动。
最直观的一次是 isolate 那个实验：同步计算 827 毫秒期间，
一个 20 毫秒的定时器**一次都没能触发**，而把同样的计算丢进 `Isolate.run` 之后，
耗时几乎没变、定时器却触发了 40 次。以前"单线程事件循环"对我来说是个名词，
现在是亲眼见过的数字。

**遗留问题**：

1. `data/books.json` 需要换成课程统一数据集，并重跑第五节的核验。
2. 给异常提示文本补断言，让"说给人听的话"也受测试保护。
3. 想再写一个用到 `finally` 的真实场景（比如自己开文件流），把清理这块补上。
4. `Stream` 只做了消费端，想试着自己用 `StreamController` 造一个流。

**下次课的预习要点**：

- 第 11 课要做网络请求，本课的 `await` + `try-catch` + `fromJson` 三件套会直接复用，
  提前看一下 `dart:io` 的 `HttpClient` 或者 `http` 包的基本用法。
- 网络请求是**最容易出错**的场景（超时、断网、404、返回体不是预期格式），
  想提前想清楚这几类错误分别该怎么提示用户——这次只练了本地文件，网络的不确定性高得多。
- 阶段作业一要把课堂作业 1~4 归并成一份报告，需要提前整理四次作业的仓库地址与关键证据。
