import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KelolaSubkategoriPage extends StatefulWidget {
  const KelolaSubkategoriPage({super.key});

  @override
  State<KelolaSubkategoriPage> createState() => _KelolaSubkategoriPageState();
}

class _KelolaSubkategoriPageState extends State<KelolaSubkategoriPage> {
  // State diubah menjadi nullable dan nilai awalnya null (kosong)
  String? _selectedView;

  @override
  Widget build(BuildContext context) {
    // Definisi warna dan gaya untuk kemudahan
    final Color primaryColor = Colors.green.shade600;
    final Color cardColor = Colors.white;
    final Color backgroundColor = Colors.grey.shade100;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Kelola Kategori',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: cardColor,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications_none, color: primaryColor),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- Tombol Toggle Atas ---
            Row(
              children: [
                _buildTopToggleButton(
                  label: 'Kategori',
                  value: 'kategori',
                  icon: Icons.category,
                ),
                const SizedBox(width: 16),
                _buildTopToggleButton(
                  label: 'Subkategori',
                  value: 'subkategori',
                  icon: Icons.check_box_outline_blank,
                  useCheckbox: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- Tampilan Konten Dinamis ---
            Expanded(child: _buildContentView()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Event',
          ),
        ],
      ),
    );
  }

  // Widget untuk membangun konten berdasarkan state _selectedView
  Widget _buildContentView() {
    if (_selectedView == 'kategori') {
      // Tampilkan pilihan Destinasi & Event
      return Column(
        children: [
          _buildMainCategoryButton(
            label: 'Destinasi',
            icon: Icons.place,
            onTap: () {
              print('Tombol Destinasi ditekan');
            },
          ),
          const SizedBox(height: 16),
          _buildMainCategoryButton(
            label: 'Event',
            icon: Icons.event,
            onTap: () {
              print('Tombol Event ditekan');
            },
          ),
        ],
      );
    } else if (_selectedView == 'subkategori') {
      // Tampilkan form subkategori
      return Center(
        child: Text(
          'Form untuk menambah Subkategori akan tampil di sini.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    } else {
      // Tampilan awal saat _selectedView masih null (kosong)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 50,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Pilih Kategori atau Subkategori untuk memulai',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
  }

  // Widget helper untuk membuat tombol toggle di bagian atas
  Widget _buildTopToggleButton({
    required String label,
    required String value,
    required IconData icon,
    bool useCheckbox = false,
  }) {
    final bool isSelected = _selectedView == value;
    final Color primaryColor = Colors.green.shade600;
    final Color cardColor = Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedView = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (useCheckbox)
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected ? primaryColor : Colors.grey,
                )
              else
                Icon(icon, color: isSelected ? primaryColor : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget helper untuk membuat tombol kategori utama (Destinasi/Event)
  Widget _buildMainCategoryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 28),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
