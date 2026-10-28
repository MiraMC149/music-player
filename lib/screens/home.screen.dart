import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music_player/constants/app_colors.dart';
import 'package:music_player/main.dart';
import 'package:music_player/widgets/search.input.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentViewIndex = 0;
  int currentSubViewIndex = 0;

  double appSpacing = 22;
  final TextEditingController _playlistController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Safe initialization after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    String? index = await prefs.getString("mainView");
    String? subIndex = await prefs.getString("subView");

    if (index != null) {
      setState(() {
        currentViewIndex = int.parse(index);
      });
    }

    if (subIndex != null) {
      setState(() {
        currentSubViewIndex = int.parse(subIndex);
      });
    }
  }

  void toggleSelection(int index) {
    setState(() {
      currentViewIndex = index;
    });
    prefs.setString("mainView", index.toString());
  }

  void toggleSubViewSelection(int index) {
    setState(() {
      currentSubViewIndex = index;
    });
    prefs.setString("subView", index.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsetsGeometry.symmetric(vertical: 22, horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                spacing: 12,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    TablerIcons.books,
                    size: 32,
                    color: AppColors.headerAccent,
                  ),
                  // Search Bar
                ],
              ),
              SizedBox(height: 8),
              Divider(color: AppColors.divider),
              _buildBackground(context),
              SizedBox(height: appSpacing),
              Row(
                spacing: 16,
                children: [
                  _buildActionButton(
                    label: "Music",
                    icon: TablerIcons.music,
                    isSelected: currentViewIndex == 0,
                    width: MediaQuery.of(context).size.width * 0.4,
                    onTap: () {
                      toggleSelection(0);
                    },
                  ),
                  _buildActionButton(
                    label: "Audiobooks",
                    icon: TablerIcons.book,
                    isSelected: currentViewIndex == 1,
                    width: MediaQuery.of(context).size.width * 0.44,
                    onTap: () {
                      toggleSelection(1);
                    },
                  ),
                ],
              ),
              SizedBox(height: appSpacing),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Your",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.header,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentViewIndex == 0 ? "library" : "audiobooks",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.headerAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    child: Row(
                      spacing: 7,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          TablerIcons.folderOpen,
                          color: Colors.grey.shade600,
                        ),
                        Text(
                          "Add folder",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Icon(
                          TablerIcons.chevronRight,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: appSpacing),
              if (currentViewIndex == 0) ...[
                // Music Libraary View
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 12,
                    children: [
                      _buildActionButton(
                        label: "Songs",
                        icon: TablerIcons.headphones,
                        isSelected: currentSubViewIndex == 0,
                        onTap: () {
                          toggleSubViewSelection(0);
                        },
                      ),
                      _buildActionButton(
                        label: "Playlists",
                        icon: TablerIcons.playlist,
                        isSelected: currentSubViewIndex == 1,
                        onTap: () {
                          toggleSubViewSelection(1);
                        },
                      ),
                      _buildActionButton(
                        label: "Artists",
                        icon: TablerIcons.microphone2,
                        isSelected: currentSubViewIndex == 2,
                        onTap: () {
                          toggleSubViewSelection(2);
                        },
                      ),
                      _buildActionButton(
                        label: "Albums",
                        icon: TablerIcons.disc,
                        isSelected: currentSubViewIndex == 3,
                        onTap: () {
                          toggleSubViewSelection(3);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: appSpacing),
                if (currentSubViewIndex == 0) ...[
                  // Songs View
                ] else if (currentSubViewIndex == 1) ...[
                  // Playlists View
                  Row(
                    spacing: 12,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.54,
                        child: TextField(
                          controller: _playlistController,
                          decoration: InputDecoration(
                            focusColor: AppColors.divider,
                            fillColor: Colors.grey.shade400,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.headerAccent,
                                width: 1,
                              ),
                            ),
                            hint: Text(
                              "New playlist name",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.grey.shade600,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade800,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildActionButton(
                        label: "Create",
                        width: MediaQuery.of(context).size.width * 0.35,
                        onTap: () {
                          // todo: create playlist
                        },
                        icon: TablerIcons.plus,
                        isSelected: true,
                      ),
                    ],
                  ),
                ] else if (currentSubViewIndex == 2) ...[
                  // Artists View
                ] else ...[
                  // Albums View
                ],
              ] else ...[
                // Audiobooks View
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required onTap,
    required IconData icon,
    required bool isSelected,
    double? width,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isSelected
              ? AppColors.headerAccent
              : AppColors.playerBackground,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 10,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.background : AppColors.header,
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.background : AppColors.header,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: AppColors.background,
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage("assets/images/background.jpg"),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 40,
            left: 20,
            child: Row(
              spacing: 12,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: AppColors.headerAccent,
                  ),
                ),
                Text(
                  "MADE FOR YOUR EVERYDAY",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.header,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 80,
            left: 20,
            child: Text(
              "Your music.",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.header,
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            top: 125,
            left: 20,
            child: Text(
              "Your rhythm.",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.headerAccent,
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: 20,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: Text(
                "All the tracks that make you, you.",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
