
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Add this import

class PaymentReportPage extends StatefulWidget {
  const PaymentReportPage({super.key});

  @override
  State<PaymentReportPage> createState() => _PaymentReportPageState();
}

class _PaymentReportPageState extends State<PaymentReportPage> {
  bool _isLoading = false;
  bool _isLocaleInitialized = false; // Add this flag
  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  Map<String, int> _ticketsByDestination = {};
  Map<String, int> _ticketsByEvent = {};
  
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';
  final List<String> _statusOptions = ['all', 'digunakan', 'belum_digunakan', 'expired'];

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _searchController.addListener(_filterPayments);
  }

  // Add this method to initialize locale
  Future<void> _initializeLocale() async {
    try {
      await initializeDateFormatting('id_ID');
      setState(() {
        _isLocaleInitialized = true;
      });
      _loadAllPayments();
    } catch (e) {
      print('Error initializing locale: $e');
      // Fallback: use without locale if initialization fails
      setState(() {
        _isLocaleInitialized = true;
      });
      _loadAllPayments();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPayments() async {
    if (!_isLocaleInitialized) return; // Wait for locale initialization
    
    setState(() => _isLoading = true);
    try {
      _allPayments.clear();
      
      // Load all collections that contain payment data
      final collections = ['payments', 'tiket', 'bookings', 'orders'];
      
      for (String collectionName in collections) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection(collectionName)
              .orderBy('created_at', descending: true)
              .get();
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            data['collection_source'] = collectionName;
            
            // Only add if it has payment-related fields
            if (_isPaymentDocument(data)) {
              _allPayments.add(data);
            }
          }
        } catch (e) {
          print('Error loading $collectionName: $e');
        }
      }
      
      // If no payments found, try to get from root documents
      if (_allPayments.isEmpty) {
        await _loadFromRootDocuments();
      }
      
      _calculateStats();
      _filteredPayments = List.from(_allPayments);
      
    } catch (e) {
      _showSnackBar('Error loading data: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFromRootDocuments() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('payments').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        _allPayments.add(data);
      }
    } catch (e) {
      print('Error loading from root: $e');
    }
  }

  bool _isPaymentDocument(Map<String, dynamic> data) {
    // Check if document has payment-related fields
    return data.containsKey('total_amount') || 
           data.containsKey('payment_id') || 
           data.containsKey('order_id') ||
           data.containsKey('user_email') ||
           (data.containsKey('status') && data.containsKey('created_at'));
  }

  void _calculateStats() {
    _ticketsByDestination.clear();
    _ticketsByEvent.clear();
    
    for (var payment in _allPayments) {
      // Count by destination
      String destinasiName = _getDestinationName(payment);
      if (destinasiName.isNotEmpty && destinasiName != 'Unknown') {
        _ticketsByDestination[destinasiName] = (_ticketsByDestination[destinasiName] ?? 0) + 1;
      }
      
      // Count by event
      String eventName = _getEventName(payment);
      if (eventName.isNotEmpty && eventName != 'Unknown Event') {
        _ticketsByEvent[eventName] = (_ticketsByEvent[eventName] ?? 0) + 1;
      }
    }
  }

  String _getDestinationName(Map<String, dynamic> payment) {
    return payment['destinasi_name']?.toString() ?? 
           payment['destinasi_data']?['namaDestinasi']?.toString() ?? 
           '';
  }

  String _getEventName(Map<String, dynamic> payment) {
    return payment['event_name']?.toString() ?? 
           payment['event_data']?['namaEvent']?.toString() ?? 
           '';
  }

  void _filterPayments() {
    List<Map<String, dynamic>> filtered = List.from(_allPayments);

    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((payment) {
        final searchFields = [
          payment['user_name']?.toString() ?? '',
          payment['user_email']?.toString() ?? '',
          payment['order_id']?.toString() ?? '',
          _getEventName(payment),
          _getDestinationName(payment),
        ].join(' ').toLowerCase();
        
        return searchFields.contains(searchTerm);
      }).toList();
    }

    if (_selectedStatus != 'all') {
      filtered = filtered.where((payment) => payment['status'] == _selectedStatus).toList();
    }

    setState(() => _filteredPayments = filtered);
  }

  String _formatCurrency(dynamic amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    if (amount == null) return formatter.format(0);
    final numAmount = amount is String ? (double.tryParse(amount) ?? 0) : amount.toDouble();
    return formatter.format(numAmount);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '-';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => PaymentDetailsDialog(payment: payment),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: !_isLocaleInitialized || _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : RefreshIndicator(
              onRefresh: _loadAllPayments,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFilters(),
                    _buildSummaryCards(),
                    if (_ticketsByDestination.isNotEmpty) _buildTicketsByDestination(),
                    if (_ticketsByEvent.isNotEmpty) _buildTicketsByEvent(),
                    _buildPaymentsList(),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2E7D32), size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Laporan Pembayaran',
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
      centerTitle: true,
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari berdasarkan nama, email, order ID, atau event...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2E7D32)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Status Tiket',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _statusOptions.map((status) => DropdownMenuItem(
              value: status,
              child: Text(status == 'all' ? 'Semua Status' : status.replaceAll('_', ' ')),
            )).toList(),
            onChanged: (value) {
              setState(() => _selectedStatus = value!);
              _filterPayments();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalPayments = _filteredPayments.length;
    final totalAmount = _filteredPayments.fold<double>(0, (sum, payment) {
      final amount = payment['total_amount'];
      return sum + (amount is String ? (double.tryParse(amount) ?? 0) : (amount ?? 0).toDouble());
    });
    final paidCount = _filteredPayments.where((p) => p['paid_at'] != null).length;
    final usedCount = _filteredPayments.where((p) => p['status'] == 'digunakan').length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildSummaryCard('Total Transaksi', totalPayments.toString(), Icons.receipt_long, Colors.blue)),
          const SizedBox(width: 8),
          Expanded(child: _buildSummaryCard('Total Pendapatan', _formatCurrency(totalAmount), Icons.attach_money, Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: _buildSummaryCard('Terbayar', paidCount.toString(), Icons.check_circle, Colors.orange)),
          const SizedBox(width: 8),
          Expanded(child: _buildSummaryCard('Terpakai', usedCount.toString(), Icons.verified, Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildTicketsByDestination() {
    return _buildTicketStatsCard('Total Tiket per Destinasi', _ticketsByDestination, const Color(0xFF2E7D32));
  }

  Widget _buildTicketsByEvent() {
    return _buildTicketStatsCard('Total Tiket per Event', _ticketsByEvent, Colors.purple);
  }

  Widget _buildTicketStatsCard(String title, Map<String, int> data, Color color) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 12),
          ...data.entries.map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(entry.key, style: GoogleFonts.poppins(fontSize: 14))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('${entry.value} tiket', 
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    if (_filteredPayments.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Tidak ada data pembayaran', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPayments.length,
      itemBuilder: (context, index) => _buildPaymentCard(_filteredPayments[index]),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final eventName = _getEventName(payment);
    final destinasiName = _getDestinationName(payment);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8)],
      ),
      child: InkWell(
        onTap: () => _showPaymentDetails(payment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payment['user_name']?.toString() ?? 'Unknown', 
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(payment['user_email']?.toString() ?? '', 
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  _buildStatusBadge(payment['status']?.toString() ?? ''),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eventName.isNotEmpty) Text('Event: $eventName', style: GoogleFonts.poppins(fontSize: 12)),
                        if (destinasiName.isNotEmpty) Text('Destinasi: $destinasiName', style: GoogleFonts.poppins(fontSize: 12)),
                        Text('Order ID: ${payment['order_id']?.toString() ?? ''}', 
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatCurrency(payment['total_amount']), 
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                      Text(_formatDate(payment['created_at']), 
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(payment['paid_at'] != null ? Icons.check_circle : Icons.pending, 
                    size: 14, color: payment['paid_at'] != null ? Colors.green : Colors.orange),
                  const SizedBox(width: 4),
                  Text(payment['paid_at'] != null ? 'Terbayar' : 'Menunggu Pembayaran', 
                    style: GoogleFonts.poppins(fontSize: 11)),
                  const SizedBox(width: 16),
                  if (payment['used_at'] != null) ...[
                    const Icon(Icons.verified, size: 14, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text('Digunakan: ${_formatDate(payment['used_at'])}', 
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.purple)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final statusConfig = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusConfig['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(statusConfig['text'], 
        style: GoogleFonts.poppins(fontSize: 10, color: statusConfig['color'], fontWeight: FontWeight.w500)),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'digunakan': return {'color': Colors.green, 'text': 'Digunakan'};
      case 'belum_digunakan': return {'color': Colors.orange, 'text': 'Belum Digunakan'};
      case 'expired': return {'color': Colors.red, 'text': 'Kadaluarsa'};
      default: return {'color': Colors.grey, 'text': status};
    }
  }
}

class PaymentDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> payment;

  const PaymentDetailsDialog({super.key, required this.payment});

  String _formatCurrency(dynamic amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    if (amount == null) return formatter.format(0);
    final numAmount = amount is String ? (double.tryParse(amount) ?? 0) : amount.toDouble();
    return formatter.format(numAmount);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '-';
    }
    
    // Use safe date formatting - fallback to basic format if locale fails
    try {
      return DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(date);
    } catch (e) {
      // Fallback to simple format if Indonesian locale fails
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinasiDetails = payment['destinasi_data'] as Map<String, dynamic>?;
    final eventDetails = payment['event_data'] as Map<String, dynamic>?;
    final transactionDetails = payment['transaction_details'] as Map<String, dynamic>?;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Detail Pembayaran', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              
              _buildDetailSection('Informasi Pelanggan', [
                _buildDetailRow('Nama', payment['user_name']?.toString() ?? '-'),
                _buildDetailRow('Email', payment['user_email']?.toString() ?? '-'),
                _buildDetailRow('User ID', payment['user_id']?.toString() ?? '-'),
              ]),
              
              _buildDetailSection('Informasi Pemesanan', [
                _buildDetailRow('Order ID', payment['order_id']?.toString() ?? '-'),
                _buildDetailRow('Payment ID', payment['payment_id']?.toString() ?? '-'),
                if (payment['event_name']?.toString().isNotEmpty == true || eventDetails?['namaEvent'] != null)
                  _buildDetailRow('Event', payment['event_name']?.toString() ?? eventDetails?['namaEvent']?.toString() ?? '-'),
                _buildDetailRow('Destinasi', payment['destinasi_name']?.toString() ?? destinasiDetails?['namaDestinasi']?.toString() ?? '-'),
                if (destinasiDetails != null) ...[
                  _buildDetailRow('Lokasi', destinasiDetails['lokasi']?.toString() ?? '-'),
                  _buildDetailRow('Jam Buka', destinasiDetails['jamBuka']?.toString() ?? '-'),
                  _buildDetailRow('Jam Tutup', destinasiDetails['jamTutup']?.toString() ?? '-'),
                  _buildDetailRow('Harga Tiket', _formatCurrency(destinasiDetails['hargaTiket'])),
                ],
                _buildDetailRow('Jumlah', payment['quantity']?.toString() ?? '1'),
                _buildDetailRow('Total', _formatCurrency(payment['total_amount'])),
                _buildDetailRow('Status', payment['status']?.toString() ?? '-'),
                _buildDetailRow('Metode Pembayaran', payment['payment_method']?.toString() ?? '-'),
              ]),
              
              if (transactionDetails != null)
                _buildDetailSection('Informasi Transaksi', [
                  _buildDetailRow('Transaction ID', transactionDetails['transaction_id']?.toString() ?? '-'),
                  _buildDetailRow('Status Transaksi', transactionDetails['transaction_status']?.toString() ?? '-'),
                  _buildDetailRow('Tipe Pembayaran', transactionDetails['payment_type']?.toString() ?? '-'),
                  _buildDetailRow('Gross Amount', transactionDetails['gross_amount']?.toString() ?? '-'),
                  _buildDetailRow('Status Code', transactionDetails['status_code']?.toString() ?? '-'),
                  _buildDetailRow('Transaction Time', transactionDetails['transaction_time']?.toString() ?? '-'),
                ]),
              
              _buildDetailSection('Waktu', [
                _buildDetailRow('Dibuat', _formatDate(payment['created_at'])),
                _buildDetailRow('Dibayar', _formatDate(payment['paid_at'])),
                _buildDetailRow('Digunakan', _formatDate(payment['used_at'])),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32))),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))),
          const Text(': '),
          Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}