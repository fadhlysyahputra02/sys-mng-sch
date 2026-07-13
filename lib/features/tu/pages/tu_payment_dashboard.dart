import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../services/payment_service.dart';
import '../../../../core/localization/app_localization.dart';

class TUPaymentDashboard extends StatefulWidget {
  final String schoolId;
  final bool hideBackButton;

  const TUPaymentDashboard({
    super.key,
    required this.schoolId,
    this.hideBackButton = false,
  });

  @override
  State<TUPaymentDashboard> createState() => _TUPaymentDashboardState();
}

class _TUPaymentDashboardState extends State<TUPaymentDashboard> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  late TabController _tabController;
  final _searchQueryController = TextEditingController();
  String _searchQuery = '';

  // Verification filter status
  String _verificationFilter = 'pending'; // 'all', 'pending', 'paid', 'unpaid'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchQueryController.dispose();
    super.dispose();
  }

  String _formatRupiah(double value) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : Colors.black;
        final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
        final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

        Widget content = Scaffold(
          backgroundColor: Colors.transparent,
          appBar: widget.hideBackButton
              ? null
              : AppBar(
                  title: Text(
                    AppLocalization.isIndonesian ? 'Manajemen Keuangan & SPP' : 'Finance & Tuition Management',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: textColor),
                    onPressed: () => Get.back(),
                  ),
                ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.hideBackButton) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalization.isIndonesian ? 'Manajemen Keuangan & SPP' : 'Finance & Tuition Management',
                          style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        _buildCreateBillButton(context, isDark),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildCreateBillButton(context, isDark),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF10B981),
                      labelColor: const Color(0xFF10B981),
                      unselectedLabelColor: textColor.withValues(alpha: 0.6),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.list_alt_rounded),
                          text: AppLocalization.isIndonesian ? 'Daftar Tagihan' : 'Bill List',
                        ),
                        Tab(
                          icon: const Icon(Icons.fact_check_rounded),
                          text: AppLocalization.isIndonesian ? 'Verifikasi Pembayaran' : 'Verify Payments',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDaftarTagihanTab(isDark, cardBg, cardBorder, textColor),
                        _buildVerifikasiTab(isDark, cardBg, cardBorder, textColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (widget.hideBackButton) {
          return content;
        } else {
          return AuthBackground(child: content);
        }
      },
    );
  }

  Widget _buildCreateBillButton(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCreateBillDialog(context, isDark),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppLocalization.isIndonesian ? 'Buat Tagihan Baru' : 'Create New Bill',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 1: DAFTAR TAGIHAN MASTER ---
  Widget _buildDaftarTagihanTab(bool isDark, Color cardBg, Color cardBorder, Color textColor) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _paymentService.getBills(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, color: textColor.withValues(alpha: 0.3), size: 64),
                const SizedBox(height: 16),
                Text(
                  AppLocalization.isIndonesian ? 'Belum ada tagihan dibuat' : 'No bills created yet',
                  style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final bill = docs[index].data();
            final title = bill['title'] ?? '-';
            final amount = (bill['amount'] ?? 0).toDouble();
            final targetClass = bill['className'] ?? (AppLocalization.isIndonesian ? 'Semua Kelas' : 'All Classes');
            final dueDateTs = bill['dueDate'] as Timestamp?;
            final desc = bill['description'] ?? '-';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${AppLocalization.isIndonesian ? "Target" : "Target"}: $targetClass • ${AppLocalization.isIndonesian ? "Jatuh Tempo" : "Due Date"}: ${_formatDate(dueDateTs)}',
                    style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
                  ),
                  trailing: Text(
                    _formatRupiah(amount),
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalization.isIndonesian ? 'Instruksi / Catatan Pembayaran:' : 'Payment Instructions / Notes:',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: VERIFIKASI PEMBAYARAN SISWA ---
  Widget _buildVerifikasiTab(bool isDark, Color cardBg, Color cardBorder, Color textColor) {
    return Column(
      children: [
        // Status filter buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('pending', AppLocalization.isIndonesian ? 'Menunggu Verifikasi' : 'Pending Verification', Colors.amber),
              const SizedBox(width: 8),
              _buildFilterChip('paid', AppLocalization.isIndonesian ? 'Lunas' : 'Paid', const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildFilterChip('unpaid', AppLocalization.isIndonesian ? 'Belum Bayar' : 'Unpaid', Colors.grey),
              const SizedBox(width: 8),
              _buildFilterChip('all', AppLocalization.isIndonesian ? 'Semua Tagihan Murid' : 'All Student Bills', Colors.indigo),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TextField(
            controller: _searchQueryController,
            style: TextStyle(color: textColor),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              hintText: AppLocalization.isIndonesian ? 'Cari nama murid, kelas, atau tagihan...' : 'Search student name, class, or bill...',
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: textColor.withValues(alpha: 0.6), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: textColor.withValues(alpha: 0.6), size: 20),
                      onPressed: () {
                        _searchQueryController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _verificationFilter == 'pending'
                ? _paymentService.getPendingStudentBills(widget.schoolId)
                : _paymentService.getAllStudentBills(widget.schoolId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
              }

              var docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                snapshot.data?.docs ?? [],
              );

              docs.sort((a, b) {
                final aTime = (a.data()['uploadedAt'] ?? a.data()['createdAt']) as Timestamp?;
                final bTime = (b.data()['uploadedAt'] ?? b.data()['createdAt']) as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              // Apply manual client-side filter if not querying pending-only
              if (_verificationFilter != 'all' && _verificationFilter != 'pending') {
                docs = docs.where((doc) => doc.data()['status'] == _verificationFilter).toList();
              }

              // Apply search query filter
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data();
                  final sName = (data['studentName'] ?? '').toString().toLowerCase();
                  final cName = (data['className'] ?? '').toString().toLowerCase();
                  final bTitle = (data['title'] ?? '').toString().toLowerCase();
                  return sName.contains(_searchQuery) ||
                      cName.contains(_searchQuery) ||
                      bTitle.contains(_searchQuery);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty_rounded, color: textColor.withValues(alpha: 0.3), size: 64),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalization.isIndonesian ? 'Tidak ada tagihan yang sesuai' : 'No matching bills found',
                        style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final studentBill = docs[index].data();
                  final docId = docs[index].id;
                  final title = studentBill['title'] ?? '-';
                  final studentName = studentBill['studentName'] ?? (AppLocalization.isIndonesian ? 'Murid' : 'Student');
                  final className = studentBill['className'] ?? '-';
                  final amount = (studentBill['amount'] ?? 0).toDouble();
                  final status = studentBill['status'] ?? 'unpaid';
                  final method = studentBill['paymentMethod'];
                  final uploadedAt = studentBill['uploadedAt'] as Timestamp?;

                  Color statusColor;
                  String statusLabel;
                  if (status == 'paid') {
                    statusColor = const Color(0xFF10B981);
                    statusLabel = AppLocalization.isIndonesian ? 'Lunas' : 'Paid';
                  } else if (status == 'pending') {
                    statusColor = Colors.amber;
                    statusLabel = AppLocalization.isIndonesian ? 'Menunggu Verifikasi' : 'Pending Verification';
                  } else {
                    statusColor = Colors.grey;
                    statusLabel = AppLocalization.isIndonesian ? 'Belum Bayar' : 'Unpaid';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentName,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                '${AppLocalization.isIndonesian ? "Kelas" : "Class"}: $className • $title',
                                style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ),
                                  if (method != null)
                                    Text(
                                      '${AppLocalization.isIndonesian ? "Metode" : "Method"}: $method',
                                      style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11),
                                    ),
                                  if (uploadedAt != null)
                                    Text(
                                      '${AppLocalization.isIndonesian ? "Tgl" : "Date"}: ${_formatDate(uploadedAt)}',
                                      style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatRupiah(amount),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            if (status == 'pending')
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _showVerificationDialog(context, docId, studentBill, isDark),
                                child: Text(
                                  AppLocalization.isIndonesian ? 'Verifikasi' : 'Verify',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              )
                            else if (status == 'unpaid')
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF10B981),
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.money_rounded, size: 16),
                                label: Text(
                                  AppLocalization.isIndonesian ? 'Bayar Tunai' : 'Pay Cash',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _showDirectPaymentDialog(context, docId, studentName, title, amount),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String status, String label, Color color) {
    final isSelected = _verificationFilter == status;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 12)),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      checkmarkColor: Colors.white,
      onSelected: (val) {
        if (val) {
          setState(() => _verificationFilter = status);
        }
      },
    );
  }

  // --- POPUPS & DIALOGS ---

  // 1. Dialog Buat Tagihan Baru
  void _showCreateBillDialog(BuildContext context, bool isDark) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController(
      text: AppLocalization.isIndonesian
          ? 'Pembayaran dapat ditransfer ke rekening Bank BNI: 123-4567-890 a.n. Bendahara Sekolah. Silakan unggah struk transfer di bawah ini.'
          : 'Payments can be transferred to Bank BNI account: 123-4567-890 on behalf of School Treasurer. Please upload your transfer receipt below.',
    );
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String? selectedClassId; // null = Semua Kelas
    String? selectedClassName;

    showDialog(
      context: context,
      builder: (context) {
        final dialogTextColor = isDark ? Colors.white : Colors.black;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              title: Text(
                AppLocalization.isIndonesian ? 'Buat Tagihan Baru' : 'Create New Bill',
                style: TextStyle(color: dialogTextColor, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: dialogTextColor),
                      decoration: _dialogInputDeco(
                        label: AppLocalization.isIndonesian ? 'Nama Tagihan / Judul' : 'Bill Title / Subject',
                        hint: AppLocalization.isIndonesian ? 'Contoh: SPP Bulan Juli 2026' : 'e.g., SPP July 2026',
                        textColor: dialogTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      style: TextStyle(color: dialogTextColor),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dialogInputDeco(
                        label: AppLocalization.isIndonesian ? 'Nominal (Rupiah)' : 'Amount (Rupiah)',
                        hint: AppLocalization.isIndonesian ? 'Contoh: 250000' : 'e.g., 250000',
                        textColor: dialogTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Dropdown Target Kelas
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .doc(widget.schoolId)
                          .collection('classes')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final classes = (snapshot.data?.docs ?? []).toList()
                          ..sort((a, b) {
                            final aName = (a.data()['namaKelas'] ?? '').toString().toLowerCase();
                            final bName = (b.data()['namaKelas'] ?? '').toString().toLowerCase();
                            return aName.compareTo(bName);
                          });
                        return DropdownButtonFormField<String>(
                          dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                          value: selectedClassId,
                          style: TextStyle(color: dialogTextColor),
                          decoration: _dialogInputDeco(
                            label: AppLocalization.isIndonesian ? 'Ditujukan Kepada' : 'Addressed To',
                            hint: '',
                            textColor: dialogTextColor,
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                AppLocalization.isIndonesian ? 'Semua Kelas (Seluruh Murid)' : 'All Classes (All Students)',
                                style: TextStyle(color: dialogTextColor),
                              ),
                            ),
                            ...classes.map((clsDoc) {
                              final data = clsDoc.data();
                              final name = data['namaKelas'] ?? 'Kelas';
                              return DropdownMenuItem<String>(
                                value: clsDoc.id,
                                child: Text(name, style: TextStyle(color: dialogTextColor)),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedClassId = val;
                              if (val != null) {
                                final matched = classes.firstWhere((element) => element.id == val);
                                selectedClassName = matched.data()['namaKelas'] ?? 'Kelas';
                              } else {
                                selectedClassName = null;
                              }
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalization.isIndonesian ? 'Jatuh Tempo:' : 'Due Date:',
                          style: TextStyle(color: dialogTextColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF10B981)),
                          label: Text(
                            DateFormat('dd MMM yyyy', AppLocalization.isIndonesian ? 'id_ID' : 'en_US').format(selectedDate),
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      style: TextStyle(color: dialogTextColor),
                      maxLines: 3,
                      decoration: _dialogInputDeco(
                        label: AppLocalization.isIndonesian ? 'Deskripsi / Instruksi Bayar' : 'Description / Payment Instructions',
                        hint: AppLocalization.isIndonesian ? 'Detail rekening transfer dll.' : 'Transfer account details, etc.',
                        textColor: dialogTextColor,
                        hasOutline: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      Get.snackbar(
                        AppLocalization.isIndonesian ? 'Validasi' : 'Validation',
                        AppLocalization.isIndonesian ? 'Nama tagihan tidak boleh kosong.' : 'Bill title cannot be empty.',
                        backgroundColor: Colors.orange,
                        colorText: Colors.black,
                      );
                      return;
                    }
                    final amt = double.tryParse(amountController.text.trim());
                    if (amt == null || amt <= 0) {
                      Get.snackbar(
                        AppLocalization.isIndonesian ? 'Validasi' : 'Validation',
                        AppLocalization.isIndonesian ? 'Nominal harus berupa angka valid di atas 0.' : 'Amount must be a valid number above 0.',
                        backgroundColor: Colors.orange,
                        colorText: Colors.black,
                      );
                      return;
                    }

                    Get.dialog(
                      const Center(child: CircularProgressIndicator()),
                      barrierDismissible: false,
                    );

                    try {
                      await _paymentService.createBill(
                        schoolId: widget.schoolId,
                        title: titleController.text.trim(),
                        amount: amt,
                        dueDate: selectedDate,
                        description: descController.text.trim(),
                        classId: selectedClassId,
                        className: selectedClassName,
                      );
                      Get.back(); // close loading
                      Navigator.pop(context); // close dialog
                      Get.snackbar(
                        AppLocalization.isIndonesian ? 'Sukses' : 'Success',
                        AppLocalization.isIndonesian
                            ? 'Tagihan berhasil dibuat dan dibagikan ke murid.'
                            : 'Bill successfully created and shared with students.',
                        backgroundColor: const Color(0xFF10B981),
                        colorText: Colors.white,
                      );
                    } catch (e) {
                      Get.back(); // close loading
                      Get.snackbar(
                        AppLocalization.isIndonesian ? 'Error' : 'Error',
                        '${AppLocalization.isIndonesian ? "Gagal membuat tagihan" : "Failed to create bill"}: $e',
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  },
                  child: Text(
                    AppLocalization.isIndonesian ? 'Simpan & Bagikan' : 'Save & Share',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 2. Dialog Verifikasi Bukti Bayar
  void _showVerificationDialog(BuildContext context, String billDocId, Map<String, dynamic> billData, bool isDark) {
    final imageBase64 = billData['buktiBase64'] as String?;
    final studentName = billData['studentName'] ?? 'Murid';
    final title = billData['title'] ?? '-';
    final amount = (billData['amount'] ?? 0).toDouble();
    final method = billData['paymentMethod'] ?? '-';

    showDialog(
      context: context,
      builder: (context) {
        final dialogTextColor = isDark ? Colors.white : Colors.black;
        final reasonController = TextEditingController();

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          title: Text(
            AppLocalization.isIndonesian ? 'Verifikasi Pembayaran' : 'Verify Payment',
            style: TextStyle(color: dialogTextColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppLocalization.isIndonesian ? "Murid" : "Student"}: $studentName',
                  style: TextStyle(color: dialogTextColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${AppLocalization.isIndonesian ? "Tagihan" : "Bill"}: $title',
                  style: TextStyle(color: dialogTextColor),
                ),
                Text(
                  '${AppLocalization.isIndonesian ? "Nominal" : "Amount"}: ${_formatRupiah(amount)}',
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
                Text(
                  '${AppLocalization.isIndonesian ? "Metode" : "Method"}: $method',
                  style: TextStyle(color: dialogTextColor.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalization.isIndonesian ? 'Bukti Transfer:' : 'Transfer Receipt:',
                  style: TextStyle(color: dialogTextColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (imageBase64 != null)
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        maxScale: 4.0,
                        child: Image.memory(
                          base64Decode(imageBase64),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: Text(
                      AppLocalization.isIndonesian ? 'Bukti gambar tidak tersedia' : 'Receipt image not available',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  style: TextStyle(color: dialogTextColor),
                  decoration: _dialogInputDeco(
                    label: AppLocalization.isIndonesian
                        ? 'Alasan Penolakan (Hanya jika DITOLAK)'
                        : 'Rejection Reason (Only if REJECTED)',
                    hint: AppLocalization.isIndonesian
                        ? 'Contoh: Struk tidak jelas atau nominal salah'
                        : 'e.g., Receipt is unclear or incorrect amount',
                    textColor: dialogTextColor,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalization.isIndonesian ? 'Tutup' : 'Close',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  Get.snackbar(
                    AppLocalization.isIndonesian ? 'Validasi' : 'Validation',
                    AppLocalization.isIndonesian
                        ? 'Mohon isi alasan penolakan terlebih dahulu.'
                        : 'Please enter the rejection reason first.',
                    backgroundColor: Colors.orange,
                    colorText: Colors.black,
                  );
                  return;
                }

                Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                try {
                  await _paymentService.updateStudentBillStatus(
                    schoolId: widget.schoolId,
                    studentBillId: billDocId,
                    status: 'unpaid',
                    rejectionReason: reason,
                  );
                  Get.back(); // loading
                  Navigator.pop(context); // dialog
                  Get.snackbar(
                    AppLocalization.isIndonesian ? 'Sukses' : 'Success',
                    AppLocalization.isIndonesian
                        ? 'Pembayaran ditolak. Murid akan diminta mengunggah ulang.'
                        : 'Payment rejected. Student will be asked to re-upload.',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                } catch (e) {
                  Get.back(); // loading
                  Get.snackbar(
                    AppLocalization.isIndonesian ? 'Error' : 'Error',
                    '${AppLocalization.isIndonesian ? "Gagal memproses penolakan" : "Failed to process rejection"}: $e',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
              child: Text(
                AppLocalization.isIndonesian ? 'Tolak Pembayaran' : 'Reject Payment',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.money_rounded, size: 16),
              onPressed: () async {
                Navigator.pop(context); // close verification dialog
                _showDirectPaymentDialog(context, billDocId, studentName, title, amount);
              },
              label: Text(
                AppLocalization.isIndonesian ? 'Bayar Tunai' : 'Pay Cash',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: () async {
                Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                try {
                  final curUser = SessionService.currentUser;
                  await _paymentService.updateStudentBillStatus(
                    schoolId: widget.schoolId,
                    studentBillId: billDocId,
                    status: 'paid',
                    verifiedBy: curUser?.nama ?? 'TU Officer',
                  );
                  Get.back(); // loading
                  Navigator.pop(context); // dialog
                  Get.snackbar(
                    AppLocalization.isIndonesian ? 'Sukses' : 'Success',
                    AppLocalization.isIndonesian
                        ? 'Pembayaran berhasil dikonfirmasi sebagai LUNAS.'
                        : 'Payment successfully confirmed as PAID.',
                    backgroundColor: const Color(0xFF10B981),
                    colorText: Colors.white,
                  );
                } catch (e) {
                  Get.back(); // loading
                  Get.snackbar(
                    AppLocalization.isIndonesian ? 'Error' : 'Error',
                    '${AppLocalization.isIndonesian ? "Gagal memproses persetujuan" : "Failed to process approval"}: $e',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
              child: Text(
                AppLocalization.isIndonesian ? 'Setujui Pembayaran' : 'Approve Payment',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // 3. Dialog Bayar Tunai Langsung
  void _showDirectPaymentDialog(BuildContext context, String billDocId, String studentName, String title, double amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogTextColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          title: Text(
            AppLocalization.isIndonesian ? 'Konfirmasi Bayar Tunai' : 'Confirm Cash Payment',
            style: TextStyle(color: dialogTextColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            AppLocalization.isIndonesian
                ? 'Apakah Anda yakin ingin memverifikasi pembayaran tunai langsung di TU?\n\n'
                    'Murid: $studentName\n'
                    'Tagihan: $title\n'
                    'Nominal: ${_formatRupiah(amount)}'
                : 'Are you sure you want to verify direct cash payment at administration office?\n\n'
                    'Student: $studentName\n'
                    'Bill: $title\n'
                    'Amount: ${_formatRupiah(amount)}',
            style: TextStyle(color: dialogTextColor.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: () async {
                Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                try {
                  final curUser = SessionService.currentUser;
                  await _paymentService.updateStudentBillStatus(
                    schoolId: widget.schoolId,
                    studentBillId: billDocId,
                    status: 'paid',
                    paymentMethod: 'Cash di TU',
                    verifiedBy: curUser?.nama ?? 'TU Officer',
                  );
                  Get.back(); // loading
                  Navigator.pop(context); // dialog
                  Get.snackbar(
                    AppLocalization.isIndonesian ? 'Sukses' : 'Success',
                    AppLocalization.isIndonesian
                        ? 'Tagihan berhasil ditandai Lunas via Cash.'
                        : 'Bill successfully marked as Paid via Cash.',
                    backgroundColor: const Color(0xFF10B981),
                    colorText: Colors.white,
                  );
                } catch (e) {
                  Get.back(); // loading
                  Get.snackbar(
                    AppLocalization.isIndonesian ? 'Error' : 'Error',
                    '${AppLocalization.isIndonesian ? "Gagal memproses pembayaran tunai" : "Failed to process cash payment"}: $e',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
              child: Text(
                AppLocalization.isIndonesian ? 'Konfirmasi Lunas' : 'Confirm Paid',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _dialogInputDeco({
    required String label,
    required String hint,
    required Color textColor,
    bool hasOutline = false,
  }) {
    final border = hasOutline
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: textColor.withValues(alpha: 0.15)),
          )
        : UnderlineInputBorder(
            borderSide: BorderSide(color: textColor.withValues(alpha: 0.15)),
          );
    final focusedBorder = hasOutline
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
          )
        : const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
          );

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: textColor.withValues(alpha: 0.65), fontSize: 13),
      hintText: hint,
      hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 13),
      enabledBorder: border,
      focusedBorder: focusedBorder,
      border: border,
    );
  }
}
