import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_notification_service.dart';

class UpdateBanner extends StatelessWidget {
  final UpdateNotification notification;
  final VoidCallback onDismiss;
  
  const UpdateBanner({
    super.key,
    required this.notification,
    required this.onDismiss,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1DB954).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.celebration,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  notification.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Hiragino Sans',
                  ),
                ),
              ),
              if (notification.dismissable)
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ],
          ),
          
          if (notification.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notification.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          GestureDetector(
            onTap: () => _openUpdateUrl(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.download,
                    color: Color(0xFF1DB954),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notification.buttonText,
                    style: const TextStyle(
                      color: Color(0xFF1DB954),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Hiragino Sans',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _openUpdateUrl() async {
    if (notification.updateUrl.isEmpty) return;
    
    final uri = Uri.parse(notification.updateUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}