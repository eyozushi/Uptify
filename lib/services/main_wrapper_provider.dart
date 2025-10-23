import 'package:flutter/material.dart';

// MainWrapperの機能にアクセスするためのコントローラー
class MainWrapperController {
  void Function()? _showFullPlayer;
  void Function()? _togglePlayPause;
  void Function()? _nextTask;
  void Function()? _previousTask;
  bool Function()? _hasActiveTasks;
  bool Function()? _isPlayerScreenVisible;
  double Function()? _getMiniPlayerHeight;

  // MainWrapperから呼び出される登録メソッド
  void register({
    required void Function() showFullPlayer,
    required void Function() togglePlayPause,
    required void Function() nextTask,
    required void Function() previousTask,
    required bool Function() hasActiveTasks,
    required bool Function() isPlayerScreenVisible,
    required double Function() getMiniPlayerHeight,
  }) {
    _showFullPlayer = showFullPlayer;
    _togglePlayPause = togglePlayPause;
    _nextTask = nextTask;
    _previousTask = previousTask;
    _hasActiveTasks = hasActiveTasks;
    _isPlayerScreenVisible = isPlayerScreenVisible;
    _getMiniPlayerHeight = getMiniPlayerHeight;
  }

  // MainWrapperから呼び出される登録解除メソッド
  void unregister() {
    _showFullPlayer = null;
    _togglePlayPause = null;
    _nextTask = null;
    _previousTask = null;
    _hasActiveTasks = null;
    _isPlayerScreenVisible = null;
    _getMiniPlayerHeight = null;
  }

  // 外部から呼び出される公開メソッド
  void showFullPlayer() => _showFullPlayer?.call();
  void togglePlayPause() => _togglePlayPause?.call();
  void nextTask() => _nextTask?.call();
  void previousTask() => _previousTask?.call();
  bool get hasActiveTasks => _hasActiveTasks?.call() ?? false;
  bool get isPlayerScreenVisible => _isPlayerScreenVisible?.call() ?? false;
  double getMiniPlayerHeight() => _getMiniPlayerHeight?.call() ?? 0.0;
}

// グローバルなMainWrapperコントローラー
final MainWrapperController mainWrapperController = MainWrapperController();

class MainWrapperProvider extends InheritedWidget {
  final MainWrapperController controller;

  const MainWrapperProvider({
    super.key,
    required this.controller,
    required Widget child,
  }) : super(child: child);

  static MainWrapperProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainWrapperProvider>();
  }

  @override
  bool updateShouldNotify(MainWrapperProvider oldWidget) {
    return controller != oldWidget.controller;
  }
}

// MainWrapperの状態にアクセスするヘルパー関数
class MainWrapperService {
  static MainWrapperController? _getController(BuildContext context) {
    final provider = MainWrapperProvider.of(context);
    return provider?.controller;
  }

  // 簡易プレイヤーが表示されているかチェック
  static bool hasMiniPlayer(BuildContext context) {
    final controller = _getController(context);
    if (controller == null) return false;
    return controller.hasActiveTasks && !controller.isPlayerScreenVisible;
  }

  // 簡易プレイヤーの高さを取得
  static double getMiniPlayerHeight(BuildContext context) {
    final controller = _getController(context);
    return controller?.getMiniPlayerHeight() ?? 0.0;
  }

  // プレイヤー画面を開く
  static void showPlayer(BuildContext context) {
    final controller = _getController(context);
    controller?.showFullPlayer();
  }

  // 再生状態をトグル
  static void togglePlayPause(BuildContext context) {
    final controller = _getController(context);
    controller?.togglePlayPause();
  }

  // 次のタスクに移動
  static void nextTask(BuildContext context) {
    final controller = _getController(context);
    controller?.nextTask();
  }

  // 前のタスクに移動
  static void previousTask(BuildContext context) {
    final controller = _getController(context);
    controller?.previousTask();
  }
}