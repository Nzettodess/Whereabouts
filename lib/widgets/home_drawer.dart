import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'credits_feedback_dialog.dart';
import '../services/services.dart';
import '../core/theme/app_colors.dart';

/// iOS-style navigation drawer with grouped sections
class HomeDrawer extends StatelessWidget {
  final User? user;
  final String? displayName;
  final String? photoUrl;
  final VoidCallback onProfileTap;
  final VoidCallback onManageGroupsTap;
  final VoidCallback onUpcomingTap;
  final VoidCallback onBirthdayBabyTap;
  final VoidCallback onRSVPManagementTap;
  final VoidCallback onSettingsTap;

  const HomeDrawer({
    super.key,
    required this.user,
    this.displayName,
    required this.photoUrl,
    required this.onProfileTap,
    required this.onManageGroupsTap,
    required this.onUpcomingTap,
    required this.onBirthdayBabyTap,
    required this.onRSVPManagementTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    
    return Drawer(
      backgroundColor: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(context, isDark, surfaceColor),
            
            const SizedBox(height: 16),
            
            // Scrollable menu items
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Navigation Section
                    _buildSectionHeader(context, 'NAVIGATION'),
                    const SizedBox(height: 8),
                    _buildGroupedSection(
                      context,
                      surfaceColor,
                      [
                        _buildMenuItem(
                          context: context,
                          icon: Icons.group_rounded,
                          iconColor: AppColors.iosPurple,
                          title: 'Groups',
                          onTap: () {
                            Navigator.pop(context);
                            onManageGroupsTap();
                          },
                        ),
                        _buildDivider(context),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.event_note_rounded,
                          iconColor: AppColors.iosOrange,
                          title: 'Upcoming',
                          onTap: () {
                            Navigator.pop(context);
                            onUpcomingTap();
                          },
                        ),
                        _buildDivider(context),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.cake_rounded,
                          iconColor: AppColors.iosPink,
                          title: 'Birthday Baby',
                          onTap: () {
                            Navigator.pop(context);
                            onBirthdayBabyTap();
                          },
                        ),
                        _buildDivider(context),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.event_available_rounded,
                          iconColor: AppColors.iosTeal,
                          title: 'RSVP',
                          onTap: () {
                            Navigator.pop(context);
                            onRSVPManagementTap();
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Settings Section
                    _buildSectionHeader(context, 'PREFERENCES'),
                    const SizedBox(height: 8),
                    _buildGroupedSection(
                      context,
                      surfaceColor,
                      [
                        _buildMenuItem(
                          context: context,
                          icon: Icons.settings_rounded,
                          iconColor: AppColors.iosGray,
                          title: 'Settings',
                          onTap: () {
                            Navigator.pop(context);
                            onSettingsTap();
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // About Section
                    _buildSectionHeader(context, 'ABOUT'),
                    const SizedBox(height: 8),
                    _buildGroupedSection(
                      context,
                      surfaceColor,
                      [
                        _buildMenuItem(
                          context: context,
                          icon: Icons.info_outline_rounded,
                          iconColor: AppColors.iosBlue,
                          title: 'About & Feedback',
                          onTap: () {
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) => const CreditsAndFeedbackDialog(),
                            );
                          },
                        ),
                        if (PWAService().shouldShowInstallButton()) ...[
                          _buildDivider(context),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.install_mobile_rounded,
                            iconColor: AppColors.iosGreen,
                            title: 'Install App',
                            onTap: () {
                              Navigator.pop(context);
                              PWAService().triggerInstall();
                            },
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Profile header with avatar and name
  Widget _buildProfileHeader(BuildContext context, bool isDark, Color surfaceColor) {
    final headerBgColor = isDark ? AppColors.iosPurple.withOpacity(0.3) : AppColors.iosPurple;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [AppColors.iosPurple.withOpacity(0.4), AppColors.iosPurple.withOpacity(0.2)]
              : [AppColors.iosPurple, AppColors.iosPurple.withOpacity(0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onProfileTap();
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: Image.network(
                    photoUrl ?? user?.photoURL ?? "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName ?? user?.displayName ?? 'User')}",
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.network(
                        "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName ?? user?.displayName ?? 'User')}",
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            displayName ?? user?.displayName ?? user?.email ?? "User",
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 18, 
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          if (user?.email != null && user?.email != displayName)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                user!.email!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75), 
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// iOS-style section header
  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: isDark ? AppColors.iosGray : AppColors.lightSecondary,
        ),
      ),
    );
  }

  /// Grouped section container with rounded corners
  Widget _buildGroupedSection(BuildContext context, Color surfaceColor, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  /// Individual menu item
  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.iosGray.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Subtle divider between menu items
  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(
        height: 0.5,
        thickness: 0.5,
        color: AppColors.getDivider(context),
      ),
    );
  }
}
