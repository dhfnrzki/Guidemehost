import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:guide_me/admin/setting.dart';
import 'package:guide_me/user/diskusiPage.dart';
import 'package:guide_me/admin/kontroll_destinasi.dart';
import 'package:guide_me/admin/kontroll_event.dart';
import 'kelola_subkategori.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guide_me/user/home.dart';
import 'package:guide_me/admin/manajemen_pegguna.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifikasi_widget.dart';
import 'laporan.dart';
import '../services/notifikasiadmin_service.dart';
import 'package:badges/badges.dart' as badges;

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => AdminPageState();
}

class AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  Map<String, int> userCounts = {};
  int touchedIndex = -1;
  StreamSubscription? _notificationSubscription;
  late AnimationController _animationController;
  bool _isDrawerOpen = false;
  String? userRole;
  bool isLoading = true;
  bool isLoadingRole = true;
  bool isLoggedIn = true;
  int _userCount = 0;
  int _categoryCount = 0;
  int _destinationCount = 0;
  int _eventCount = 0;
  int _selectedNavIndex = 0;
  int _notificationCount = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationsPage notificationWidget = NotificationsPage();
  final NotificationService _notificationService = NotificationService();

  final List<Color> _barColors = [
    Color(0xFF5ABB4D),
    Colors.blueAccent.shade700,
    Colors.purpleAccent.shade700,
    Colors.orangeAccent.shade700,
    Colors.redAccent.shade700,
  ];

  final Color _backgroundColor = Color(0xFFF8F9FA);
  final Color _cardBackgroundColor = Color(0xFFFFFFFF);
  final Color _primaryGreen = Color(0xFF5ABB4D);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Inisialisasi login dan data pengguna

    _checkUserRole();
    fetchUserData();

    // Inisialisasi notifikasi
    _notificationService.initNotificationListeners();
    _fetchNotificationCount();

    // Inisialisasi animasi
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeAdminData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardCounts() async {
    try {
      final responses = await Future.wait([
        _firestore.collection('users').get(),
        _firestore.collection('categories').get(),
        _firestore.collection('subcategories').get(),
        _firestore.collection('destinasi').get(),
        _firestore.collection('events').get(),
      ]);
      if (mounted) {
        setState(() {
          _userCount = responses[0].size;
          _categoryCount = responses[1].size + responses[2].size;
          _destinationCount = responses[3].size;
          _eventCount = responses[4].size;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard counts: $e");
    }
  }

  Future<void> _initializeAdminData() async {
    setState(() => isLoading = true);
    // Menjalankan semua proses fetch data secara paralel untuk efisiensi
    await Future.wait([
      _checkUserRole(),
      _fetchDashboardCounts(),
      fetchUserData(), // Mengambil data untuk chart
      _fetchNotificationCount(), // Menggunakan fungsi notifikasi dari kode pertama
    ]);
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // Add method to fetch notification count
  Future<void> _fetchNotificationCount() async {
    try {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        // <-- Langganan disimpan
        if (mounted) {
          setState(() {
            _notificationCount = snapshot.docs.length;
          });
        }
      });

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .get();

      // Update state with notification count
      if (mounted) {
        setState(() {
          _notificationCount = snapshot.docs.length;
        });
      }

      // Set up listener for real-time updates - gunakan nama koleksi yang sama
      FirebaseFirestore.instance
          .collection(
            'admin_notifications',
          ) // Ubah dari 'notifications' ke 'admin_notifications'
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _notificationCount = snapshot.docs.length;
          });
        }
      });
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
    }
  }

  Future<String?> getUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'];
      }
    }
    return null;
  }

  Future<void> _checkUserRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            userRole = data['role'];
          });
        }
      }
    }
  }

  Future<void> fetchUserData() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();

      Map<String, int> counts = {};
      for (var doc in snapshot.docs) {
        if (doc.data().containsKey('createdAt')) {
          Timestamp createdAt = doc['createdAt'];
          DateTime date = createdAt.toDate();
          String key = DateFormat('MMM yyyy').format(date);

          counts[key] = (counts[key] ?? 0) + 1;
        }
      }

      final sortedKeys = counts.keys.toList()
        ..sort(
          (a, b) => DateFormat(
            'MMM yyyy',
          ).parse(a).compareTo(DateFormat('MMM yyyy').parse(b)),
        );

      if (mounted) {
        setState(() {
          userCounts = {for (var k in sortedKeys) k: counts[k]!};
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  void _toggleDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  // Called when drawer is opened
  void _onDrawerChanged(bool isOpened) {
    if (isOpened) {
      _animationController.forward();
      setState(() {
        _isDrawerOpen = true;
      });
    } else {
      _animationController.reverse();
      setState(() {
        _isDrawerOpen = false;
      });
    }
  }

  // Navigate to notification page instead of showing modal
  void _navigateToNotificationsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
  }

  Color getBarColor(int index) {
    return _barColors[index % _barColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _backgroundColor,
        drawer: _buildDrawer(),
        onDrawerChanged: _onDrawerChanged,
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryGreen))
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _initializeAdminData,
        color: _primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildNavigationGrid(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Lihat Statistik Pengguna'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    minimumSize: const Size(double.infinity, 50),
                    side: BorderSide(color: _primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _showChartModal,
                ),
              ),
              const SizedBox(height: 24),
              // Info Cards dari kode pertama
              _buildInfoCard(
                'Total Pengguna',
                _userCount.toString(),
                Icons.people,
                Colors.blue,
              ),
              _buildInfoCard(
                'Pengguna Baru Bulan Ini',
                userCounts.isEmpty ? '0' : userCounts.values.last.toString(),
                Icons.person_add,
                Colors.orange,
              ),
              _buildInfoCard(
                'Rata-rata Pengguna per Bulan',
                userCounts.isEmpty
                    ? '0'
                    : (userCounts.values.fold(0, (sum, count) => sum + count) /
                            userCounts.length)
                        .toStringAsFixed(1),
                Icons.analytics,
                Colors.purple,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _animationController,
              color: Colors.black87,
            ),
            onPressed: _toggleDrawer,
          ),
          Text(
            'Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black87,
                  size: 28,
                ),
                onPressed: _navigateToNotificationsPage,
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        '$_notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      childAspectRatio: 1.1,
      children: [
        _buildNavCard(
          count: _userCount,
          label: 'Kelola Pengguna',
          icon: Icons.people_outline,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => KelolaUserPage()),
          ),
        ),
        _buildNavCard(
          count: _categoryCount,
          label: 'Kelola Kategori',
          icon: Icons.category_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const KelolaSubkategoriPage(),
            ),
          ),
        ),
        _buildNavCard(
          count: _destinationCount,
          label: 'Kelola Destinasi',
          icon: Icons.map_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const KelolaDestinasiPage(),
            ),
          ),
        ),
        _buildNavCard(
          count: _eventCount,
          label: 'Kelola Event',
          icon: Icons.event_note_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const KontrollEventPage(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavCard({
    required int count,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryGreen, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _primaryGreen.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(icon, size: 36, color: Colors.black),
                ],
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChartModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child:
                      _buildChartCard(), // Menampilkan card chart di dalam modal
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: userCounts.isEmpty
            ? Center(child: CircularProgressIndicator(color: _primaryGreen))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Jumlah Pengguna per Bulan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        maxY: (userCounts.values.isEmpty
                                ? 0
                                : (userCounts.values.toList()..sort()).last) *
                            1.2,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBorder: const BorderSide(
                              color: Colors.black,
                            ),
                            getTooltipItem: (
                              group,
                              groupIndex,
                              rod,
                              rodIndex,
                            ) {
                              if (group.x < 0 || group.x >= userCounts.length) {
                                return null;
                              }
                              return BarTooltipItem(
                                '${userCounts.values.elementAt(group.x)} pengguna',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          touchCallback: (event, barTouchResponse) {
                            setState(() {
                              if (barTouchResponse?.spot != null &&
                                  event is! FlTapUpEvent &&
                                  event is! FlPanEndEvent) {
                                touchedIndex = barTouchResponse!
                                    .spot!.touchedBarGroupIndex;
                              } else {
                                touchedIndex = -1;
                              }
                            });
                          },
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey[300],
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, _) {
                                int index = value.toInt();
                                if (index < 0 || index >= userCounts.length) {
                                  return const SizedBox();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    userCounts.keys.elementAt(index),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black54,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox();
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        barGroups: userCounts.entries
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (entry) => BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.value.toDouble(),
                                    color: touchedIndex == entry.key
                                        ? _primaryGreen
                                        : _primaryGreen.withOpacity(
                                            0.6,
                                          ),
                                    width: 22,
                                    borderRadius: BorderRadius.circular(
                                      0,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 40, bottom: 20),
            color: const Color(0xFFF8F9FA),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _primaryGreen,
                  child: const Text(
                    'A',
                    style: TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Admin',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF8F9FA),
              child: Column(
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    isActive: true, // Asumsi halaman ini selalu aktif
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'Manajemen Pengguna',
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => KelolaUserPage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.analytics,
                    title: 'Laporan', // Ganti ke halaman laporan Anda
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentReportPage()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Pengaturan',
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingPage()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    onTap: () async {
                      _scaffoldKey.currentState?.closeDrawer();
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Konfirmasi Logout'),
                          content: const Text(
                            'Apakah Anda yakin ingin keluar?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                      if (shouldLogout == true) {
                        await _auth.signOut();
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomePage(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Container(
      color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFF8F9FA),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? _primaryGreen : Colors.grey[600],
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isActive ? _primaryGreen : Colors.black87,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
    );
  }
}

class AdminBottomNavBar extends StatelessWidget {
  final int curentindex;
  const AdminBottomNavBar({super.key, required this.curentindex});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF5ABB4D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            icon: Icons.map_outlined,
            index: 0,
            page: const KelolaDestinasiPage(), // Pastikan halaman ini ada
          ),
          _buildNavItem(
            context,
            icon: Icons.dashboard_customize_outlined,
            index: 1,
            page: const AdminPage(),
          ),
          _buildNavItem(
            context,
            icon: Icons.event_note_outlined,
            index: 2,
            page: const KontrollEventPage(), // Pastikan halaman ini ada
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required int index,
    required Widget page,
  }) {
    final isSelected = curentindex == index;
    return InkWell(
      onTap: () {
        if (!isSelected) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
