// widgets/onboarding/progress_indicator.dart - 進捗インジケーター
import 'package:flutter/material.dart';
import '../../models/onboarding_data.dart';

class OnboardingProgressIndicator extends StatefulWidget {
  final int currentStep;
  final int totalSteps;
  final double progress;

  const OnboardingProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.progress,
  });

  @override
  State<OnboardingProgressIndicator> createState() => _OnboardingProgressIndicatorState();
}

class _OnboardingProgressIndicatorState extends State<OnboardingProgressIndicator>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _progressController.forward();
  }

  @override
  void didUpdateWidget(OnboardingProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.progress != oldWidget.progress) {
      _progressAnimation = Tween<double>(
        begin: oldWidget.progress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ));
      
      _progressController.reset();
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ステップ表示
          _buildStepIndicator(),
          
          const SizedBox(height: 16),
          
          // プログレスバー
          _buildProgressBar(),
          
          const SizedBox(height: 12),
          
          // ステップ名と説明
          _buildStepInfo(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.totalSteps, (index) {
        final isCompleted = index < widget.currentStep;
        final isCurrent = index == widget.currentStep;
        final isUpcoming = index > widget.currentStep;
        
        return _buildStepCircle(
          stepNumber: index + 1,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isUpcoming: isUpcoming,
        );
      }),
    );
  }

  Widget _buildStepCircle({
    required int stepNumber,
    required bool isCompleted,
    required bool isCurrent,
    required bool isUpcoming,
  }) {
    Color backgroundColor;
    Color textColor;
    IconData? icon;
    
    if (isCompleted) {
      backgroundColor = const Color(0xFF1DB954);
      textColor = Colors.white;
      icon = Icons.check;
    } else if (isCurrent) {
      backgroundColor = const Color(0xFF1DB954);
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.white.withOpacity(0.2);
      textColor = Colors.white.withOpacity(0.6);
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: isCurrent ? [
          BoxShadow(
            color: const Color(0xFF1DB954).withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: textColor,
                  key: ValueKey('icon_$stepNumber'),
                )
              : Text(
                  '$stepNumber',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFamily: 'Hiragino Sans',
                  ),
                  key: ValueKey('text_$stepNumber'),
                ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1DB954),
                    Color(0xFF1ED760),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1DB954).withOpacity(0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepInfo() {
    final currentStepEnum = OnboardingStep.values[widget.currentStep];
    final progressPercentage = (widget.progress * 100).round();
    
    return Column(
      children: [
        Text(
          currentStepEnum.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currentStepEnum.description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
            fontFamily: 'Hiragino Sans',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '$progressPercentage% 完了',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1DB954),
            fontFamily: 'Hiragino Sans',
          ),
        ),
      ],
    );
  }
}

// シンプル版のプログレスバー（必要に応じて使用）
class SimpleProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;

  const SimpleProgressBar({
    super.key,
    required this.progress,
    this.height = 4.0,
    this.backgroundColor,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: progressColor ?? const Color(0xFF1DB954),
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

// ドット形式のプログレスインジケーター
class DotProgressIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final double dotSize;
  final Color? activeColor;
  final Color? inactiveColor;

  const DotProgressIndicator({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    this.dotSize = 8.0,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? dotSize * 2 : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: isActive
                ? (activeColor ?? const Color(0xFF1DB954))
                : (inactiveColor ?? Colors.white.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(dotSize / 2),
          ),
        );
      }),
    );
  }
}