import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_tokens.dart';

/// 加减按钮控制组件
class PlusMinusControl extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged; // 改为可选，null表示禁用
  final Color? activeColor;

  const PlusMinusControl({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
    this.activeColor,
  });

  @override
  State<PlusMinusControl> createState() => _PlusMinusControlState();
}

class _PlusMinusControlState extends State<PlusMinusControl> {
  Timer? _timer;
  Timer? _speedTimer1;
  Timer? _speedTimer2;
  bool _isPressing = false;

  bool get _enabled => widget.onChanged != null;

  @override
  void dispose() {
    _timer?.cancel();
    _speedTimer1?.cancel();
    _speedTimer2?.cancel();
    super.dispose();
  }

  void _startTimer(bool isIncrement) {
    if (!_enabled) return;
    _isPressing = true;
    
    // 300ms后开始持续触发
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (_isPressing) {
        // 开始每100ms触发一次
        _startPeriodicTimer(isIncrement, const Duration(milliseconds: 100));
        
        // 按住600ms后改为每50ms触发一次
        _speedTimer1 = Timer(const Duration(milliseconds: 600), () {
          if (_isPressing) {
            _timer?.cancel();
            _startPeriodicTimer(isIncrement, const Duration(milliseconds: 50));
          }
        });
        
        // 按住1秒后改为每20ms触发一次
        _speedTimer2 = Timer(const Duration(milliseconds: 1000), () {
          if (_isPressing) {
            _timer?.cancel();
            _startPeriodicTimer(isIncrement, const Duration(milliseconds: 20));
          }
        });
      }
    });
  }

  void _startPeriodicTimer(bool isIncrement, Duration interval) {
    _timer = Timer.periodic(interval, (timer) {
      if (_isPressing) {
        _updateValue(isIncrement);
      } else {
        timer.cancel();
      }
    });
  }

  void _stopTimer() {
    _isPressing = false;
    _timer?.cancel();
    _speedTimer1?.cancel();
    _speedTimer2?.cancel();
    _timer = null;
    _speedTimer1 = null;
    _speedTimer2 = null;
  }

  void _updateValue(bool isIncrement) {
    if (!_enabled) return;
    final newValue = isIncrement 
        ? (widget.value + 1).clamp(widget.min, widget.max)
        : (widget.value - 1).clamp(widget.min, widget.max);
    if (newValue != widget.value) {
      widget.onChanged!(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? AppTokens.primary;
    final canDecrease = _enabled && widget.value > widget.min;
    final canIncrease = _enabled && widget.value < widget.max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 减号按钮
        GestureDetector(
          onTap: canDecrease ? () => _updateValue(false) : null,
          onTapDown: canDecrease ? (_) => _startTimer(false) : null,
          onTapUp: (_) => _stopTimer(),
          onTapCancel: () => _stopTimer(),
          child: Container(
            width: 40,
            height: 28,
            decoration: BoxDecoration(
              color: canDecrease ? AppTokens.surface : AppTokens.surface.withValues(alpha: 0.3),
              border: Border.all(
                color: canDecrease ? color.withValues(alpha: 0.5) : AppTokens.keyOff.withValues(alpha: 0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
            child: Icon(
              Icons.remove,
              size: 16,
              color: canDecrease ? color : AppTokens.keyOff.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 加号按钮
        GestureDetector(
          onTap: canIncrease ? () => _updateValue(true) : null,
          onTapDown: canIncrease ? (_) => _startTimer(true) : null,
          onTapUp: (_) => _stopTimer(),
          onTapCancel: () => _stopTimer(),
          child: Container(
            width: 40,
            height: 28,
            decoration: BoxDecoration(
              color: canIncrease ? AppTokens.surface : AppTokens.surface.withValues(alpha: 0.3),
              border: Border.all(
                color: canIncrease ? color.withValues(alpha: 0.5) : AppTokens.keyOff.withValues(alpha: 0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
            child: Icon(
              Icons.add,
              size: 16,
              color: canIncrease ? color : AppTokens.keyOff.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}
