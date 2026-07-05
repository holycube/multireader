import 'package:flutter/material.dart';



import '../../../theme/app_design_tokens.dart';



/// 个人中心渐变头部：默认头像、昵称与阅读状态语。

class ProfileHeader extends StatelessWidget {

  const ProfileHeader({

    super.key,

    this.statusText = '点击查看阅读统计',

    this.loading = false,

    this.onTap,

  });



  final String statusText;

  final bool loading;

  final VoidCallback? onTap;



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final accentLight = theme.colorScheme.primaryContainer;

    final subtitle = loading ? '加载中…' : statusText;



    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        child: Container(

          width: double.infinity,

          decoration: BoxDecoration(

            gradient: LinearGradient(

              begin: Alignment.topLeft,

              end: Alignment.bottomRight,

              colors: [

                accentLight,

                const Color(0xFFFFF8E7),

                theme.colorScheme.surface,

              ],

            ),

          ),

          child: SafeArea(

            bottom: false,

            child: Padding(

              padding: const EdgeInsets.fromLTRB(

                AppSpacing.xxl,

                AppSpacing.xxl,

                AppSpacing.xxl,

                28,

              ),

              child: Row(

                children: [

                  CircleAvatar(

                    radius: 36,

                    backgroundColor:

                        theme.colorScheme.primary.withValues(alpha: 0.15),

                    child: Icon(

                      Icons.person,

                      size: 40,

                      color: theme.colorScheme.primary,

                    ),

                  ),

                  const SizedBox(width: AppSpacing.lg),

                  Expanded(

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Text(

                          '阅读者',

                          style: theme.textTheme.titleLarge?.copyWith(

                            fontWeight: FontWeight.w600,

                          ),

                        ),

                        const SizedBox(height: 6),

                        Text(

                          subtitle,

                          style: theme.textTheme.bodyMedium?.copyWith(

                            color: theme.colorScheme.onSurfaceVariant,

                          ),

                        ),

                      ],

                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

}


