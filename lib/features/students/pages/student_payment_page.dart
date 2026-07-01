import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../authentication/widgets/auth_background.dart';
import '../../tu/services/payment_service.dart';

class StudentPaymentPage extends StatefulWidget {
  final String schoolId;
  final String studentId;
  final String studentName;

  const StudentPaymentPage({
    super.key,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentPaymentPage> createState() => _StudentPaymentPageState();
}

class _StudentPaymentPageState extends State<StudentPaymentPage> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatRupiah(double value) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return AuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Keuangan & SPP - ${widget.studentName}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: () => Get.back(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
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
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 11),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  tabs: const [
                    Tab(text: 'Belum Bayar'),
                    Tab(text: 'Verifikasi'),
                    Tab(text: 'Lunas'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _paymentService.getStudentBills(widget.schoolId, widget.studentId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
                    }

                    final allBills = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                      snapshot.data?.docs ?? [],
                    );

                    allBills.sort((a, b) {
                      final aTime = a.data()['createdAt'] as Timestamp?;
                      final bTime = b.data()['createdAt'] as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                    final unpaidBills = allBills.where((doc) => doc.data()['status'] == 'unpaid').toList();
                    final pendingBills = allBills.where((doc) => doc.data()['status'] == 'pending').toList();
                    final paidBills = allBills.where((doc) => doc.data()['status'] == 'paid').toList();

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBillsList(unpaidBills, 'unpaid', isDark, cardBg, cardBorder, textColor),
                        _buildBillsList(pendingBills, 'pending', isDark, cardBg, cardBorder, textColor),
                        _buildBillsList(paidBills, 'paid', isDark, cardBg, cardBorder, textColor),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillsList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bills,
    String type,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color textColor,
  ) {
    if (bills.isEmpty) {
      String emptyMsg = 'Tidak ada tagihan';
      IconData emptyIcon = Icons.check_circle_outline_rounded;
      Color iconColor = const Color(0xFF10B981);

      if (type == 'unpaid') {
        emptyMsg = 'Semua tagihan Anda telah lunas!';
      } else if (type == 'pending') {
        emptyMsg = 'Tidak ada pembayaran yang sedang diproses.';
        emptyIcon = Icons.hourglass_empty_rounded;
        iconColor = Colors.amber;
      } else {
        emptyMsg = 'Belum ada riwayat pembayaran lunas.';
        emptyIcon = Icons.receipt_long_rounded;
        iconColor = Colors.grey;
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, color: iconColor.withValues(alpha: 0.4), size: 64),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
              style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final doc = bills[index];
        final bill = doc.data();
        final billDocId = doc.id;
        final title = bill['title'] ?? '-';
        final amount = (bill['amount'] ?? 0).toDouble();
        final dueDateTs = bill['dueDate'] as Timestamp?;
        final desc = bill['description'] ?? '-';
        final rejectionReason = bill['rejectionReason'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: (type == 'paid' ? const Color(0xFF10B981) : (type == 'pending' ? Colors.amber : Colors.red))
                  .withValues(alpha: 0.15),
              child: Icon(
                type == 'paid' ? Icons.check_rounded : (type == 'pending' ? Icons.hourglass_bottom_rounded : Icons.priority_high_rounded),
                color: type == 'paid' ? const Color(0xFF10B981) : (type == 'pending' ? Colors.amber : Colors.red),
              ),
            ),
            title: Text(
              title,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'Jatuh Tempo: ${_formatDate(dueDateTs)}',
              style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
            ),
            trailing: Text(
              _formatRupiah(amount),
              style: TextStyle(
                color: type == 'paid' ? const Color(0xFF10B981) : const Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ditolak TU: $rejectionReason\nMohon unggah ulang bukti yang valid.',
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Instruksi Pembayaran:',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (type == 'unpaid')
                      Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Bayar & Unggah Bukti', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _showUploadReceiptSheet(context, billDocId, title, amount, isDark),
                        ),
                      )
                    else if (type == 'pending')
                      Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Struk telah terunggah pada ${_formatDate(bill['uploadedAt'] as Timestamp?)}. Menunggu konfirmasi dari petugas TU.',
                              style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      )
                    else if (type == 'paid')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lunas diverifikasi oleh ${bill['verifiedBy'] ?? 'Petugas TU'} pada ${_formatDate(bill['verifiedAt'] as Timestamp?)}',
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUploadReceiptSheet(BuildContext context, String studentBillId, String title, double amount, bool isDark) {
    String? localBase64;
    String selectedMethod = 'Transfer Bank';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final sheetTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: source,
                  maxWidth: 700,
                  maxHeight: 700,
                  imageQuality: 75,
                );
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setSheetState(() => localBase64 = base64Encode(bytes));
                }
              } catch (e) {
                Get.snackbar('Error', 'Gagal mengambil gambar: $e', backgroundColor: Colors.red, colorText: Colors.white);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Konfirmasi Pembayaran',
                    style: TextStyle(color: sheetTextColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$title - ${_formatRupiah(amount)}',
                    style: TextStyle(color: sheetTextColor.withValues(alpha: 0.6), fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                    value: selectedMethod,
                    style: TextStyle(color: sheetTextColor),
                    decoration: const InputDecoration(labelText: 'Metode Pembayaran'),
                    items: ['Transfer Bank', 'Virtual Account', 'E-Wallet', 'Lainnya']
                        .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => selectedMethod = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bukti Pembayaran / Struk:',
                    style: TextStyle(color: sheetTextColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  if (localBase64 != null)
                    Stack(
                      children: [
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              base64Decode(localBase64!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withValues(alpha: 0.6),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => setSheetState(() => localBase64 = null),
                            ),
                          ),
                        )
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
                            label: Text('Galeri', style: TextStyle(color: sheetTextColor)),
                            onPressed: () => pickImage(ImageSource.gallery),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981)),
                            label: Text('Kamera', style: TextStyle(color: sheetTextColor)),
                            onPressed: () => pickImage(ImageSource.camera),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: localBase64 == null
                          ? null
                          : () async {
                              Get.back(); // close sheet
                              Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                              try {
                                await _paymentService.uploadReceipt(
                                  schoolId: widget.schoolId,
                                  studentBillId: studentBillId,
                                  buktiBase64: localBase64!,
                                  paymentMethod: selectedMethod,
                                );
                                Get.back(); // close loading
                                Get.snackbar(
                                  'Berhasil',
                                  'Bukti transfer berhasil dikirim. Menunggu verifikasi petugas TU.',
                                  backgroundColor: const Color(0xFF10B981),
                                  colorText: Colors.white,
                                );
                              } catch (e) {
                                Get.back(); // close loading
                                Get.snackbar('Error', 'Gagal mengirim bukti transfer: $e', backgroundColor: Colors.red, colorText: Colors.white);
                              }
                            },
                      child: const Text('Kirim Bukti Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
