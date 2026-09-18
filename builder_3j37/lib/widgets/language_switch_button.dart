import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_service.dart';
import '../theme/app_tokens.dart';

class LanguageSwitchButton extends StatelessWidget {
  final bool highlight;
  
  const LanguageSwitchButton({
    super.key,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleService>(
      builder: (context, localeService, child) {
        final isChinese = localeService.isChinese;
        final bgColor = highlight ? AppTokens.surfaceAlt : AppTokens.surface;
        final borderColor = highlight ? AppTokens.primary : AppTokens.textSecondary;
        
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppTokens.radius),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppTokens.buttonShadow,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left side - Chinese
                InkWell(
                  onTap: () {
                    debugPrint('[LanguageSwitch] Setting locale to zh_CN');
                    localeService.setLocale(const Locale('zh', 'CN'));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isChinese ? AppTokens.primary : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        '中文',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isChinese ? AppTokens.onPrimary : AppTokens.textPrimary,
                          fontFamily: AppTokens.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Divider - full height
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: borderColor,
                  indent: 0,
                  endIndent: 0,
                ),
                
                // Right side - English
                InkWell(
                  onTap: () {
                    debugPrint('[LanguageSwitch] Setting locale to en_US');
                    localeService.setLocale(const Locale('en', 'US'));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: !isChinese ? AppTokens.primary : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        'EN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: !isChinese ? AppTokens.onPrimary : AppTokens.textPrimary,
                          fontFamily: AppTokens.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
