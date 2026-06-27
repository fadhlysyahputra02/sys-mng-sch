import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../authentication/widgets/auth_background.dart';

class SchoolUsersDetailPage extends StatefulWidget {
  final Map<String, dynamic> school;

  const SchoolUsersDetailPage({super.key, required this.school});

  @override
  State<SchoolUsersDetailPage> createState() => _SchoolUsersDetailPageState();
}

class _SchoolUsersDetailPageState extends State<SchoolUsersDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _searchController.clear();
        _searchQuery = '';
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteUser({
    required String? uid,
    required String documentId,
    required String role,
    required String name,
  }) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == currentUserUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak dapat menghapus akun Anda sendiri.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Hapus Pengguna', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus pengguna "$name" (${role.toUpperCase()})?\n\nTindakan ini akan menghapus data dari database dan akun login (Authentication) secara permanen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _deleteUser(
                  uid: uid,
                  documentId: documentId,
                  role: role,
                  name: name,
                );
              },
              child: const Text('Hapus Permanen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUser({
    required String? uid,
    required String documentId,
    required String role,
    required String name,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final firestore = FirebaseFirestore.instance;

      if (role == 'student') {
        await firestore
            .collection('schools')
            .doc(_schoolId)
            .collection('students')
            .doc(documentId)
            .delete();
        if (uid != null && uid.isNotEmpty) {
          await firestore.collection('users').doc(uid).delete();
        }
      } else if (role == 'teacher') {
        await firestore
            .collection('schools')
            .doc(_schoolId)
            .collection('teachers')
            .doc(documentId)
            .delete();
        if (uid != null && uid.isNotEmpty) {
          await firestore.collection('users').doc(uid).delete();
        }
      } else {
        await firestore.collection('users').doc(documentId).delete();
      }

      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pengguna $name berhasil dihapus.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus pengguna: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String get _schoolId => widget.school['domain'] ?? '';
  String get _schoolName => widget.school['namaSekolah'] ?? 'Sekolah';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : Colors.black;
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: SafeArea(
              child: Column(
                children: [
                  // App Bar Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _schoolName,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Daftar & Statistik Pengguna Sekolah',
                                style: TextStyle(fontSize: 12, color: subTextColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Counts / Statistics Dashboard Card
                  _buildCountsDashboard(cardBgColor, borderColor, textColor, subTextColor),

                  const SizedBox(height: 16),

                  // Search Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Cari berdasarkan nama/identitas...',
                        hintStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: subTextColor),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                        ),
                        filled: true,
                        fillColor: cardBgColor,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab Bar Selector
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF6366F1),
                    unselectedLabelColor: subTextColor,
                    indicatorColor: const Color(0xFF6366F1),
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Murid'),
                      Tab(text: 'Guru'),
                      Tab(text: 'Admin'),
                      Tab(text: 'TU'),
                      Tab(text: 'Petugas'),
                    ],
                  ),

                  // Tab Body
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildStudentsTab(cardBgColor, borderColor, textColor, subTextColor),
                        _buildTeachersTab(cardBgColor, borderColor, textColor, subTextColor),
                        _buildRoleUsersTab('school_admin', cardBgColor, borderColor, textColor, subTextColor),
                        _buildRoleUsersTab('tu', cardBgColor, borderColor, textColor, subTextColor),
                        _buildRoleUsersTab('officer', cardBgColor, borderColor, textColor, subTextColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Dashboard ringkasan user
  Widget _buildCountsDashboard(Color bg, Color border, Color text, Color subtext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RINGKASAN PENGGUNA',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtext, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCountItem('Murid', _getStudentsCountStream(), const Color(0xFF0EA5E9), text),
                _buildCountItem('Guru', _getTeachersCountStream(), const Color(0xFF10B981), text),
                _buildCountItem('Admin', _getRoleUsersCountStream('school_admin'), const Color(0xFFEC4899), text),
                _buildCountItem('TU', _getRoleUsersCountStream('tu'), const Color(0xFFF59E0B), text),
                _buildCountItem('Petugas', _getRoleUsersCountStream('officer'), const Color(0xFF8B5CF6), text),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountItem(String label, Stream<int> countStream, Color dotColor, Color textColor) {
    return Expanded(
      child: StreamBuilder<int>(
        stream: countStream,
        builder: (context, snapshot) {
          final countVal = snapshot.data ?? 0;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    countVal.toString(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          );
        },
      ),
    );
  }

  // Streams untuk statistik hitungan
  Stream<int> _getStudentsCountStream() {
    return FirebaseFirestore.instance
        .collection('schools')
        .doc(_schoolId)
        .collection('students')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> _getTeachersCountStream() {
    return FirebaseFirestore.instance
        .collection('schools')
        .doc(_schoolId)
        .collection('teachers')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> _getRoleUsersCountStream(String role) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('schoolId', isEqualTo: _schoolId)
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Tab 1: Murid
  Widget _buildStudentsTab(Color bg, Color border, Color text, Color subtext) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('students')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        
        final filtered = docs.where((doc) {
          final name = (doc.data()['nama'] ?? '').toString().toLowerCase();
          final nis = (doc.data()['nis'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || nis.contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) return _buildEmptyPlaceholder('Murid');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final data = filtered[index].data();
            final name = data['nama'] ?? 'Tanpa Nama';
            final nis = data['nis'] ?? '-';
            final gender = data['gender'] ?? '-';
            final alamat = data['alamat'] ?? '-';
            final tglLahir = data['tanggalLahir'] ?? '-';
            final angkatan = data['angkatan'] ?? '-';
            final isRegister = data['sudahRegister'] ?? false;
            final active = data['aktif'] ?? true;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: text),
                            ),
                            const SizedBox(height: 6),
                            _buildStatusBadge(active, isRegister, lulus: data['lulus'] == true),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                        onPressed: () => _confirmDeleteUser(
                          uid: data['uid'] ?? '',
                          documentId: filtered[index].id,
                          role: 'student',
                          name: name,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildDetailRow('NIS', nis, text),
                  _buildDetailRow('Jenis Kelamin', gender, text),
                  _buildDetailRow('Tanggal Lahir', tglLahir, text),
                  _buildDetailRow('Angkatan', angkatan, text),
                  _buildDetailRow('Alamat', alamat, text),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Tab 2: Guru
  Widget _buildTeachersTab(Color bg, Color border, Color text, Color subtext) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('teachers')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        
        final filtered = docs.where((doc) {
          final name = (doc.data()['nama'] ?? '').toString().toLowerCase();
          final nip = (doc.data()['nip'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || nip.contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) return _buildEmptyPlaceholder('Guru');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final data = filtered[index].data();
            final name = data['nama'] ?? 'Tanpa Nama';
            final nip = data['nip'] ?? '-';
            final gender = data['gender'] ?? '-';
            final alamat = data['alamat'] ?? '-';
            final isRegister = data['sudahRegister'] ?? false;
            final active = data['aktif'] ?? true;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: text),
                            ),
                            const SizedBox(height: 6),
                            _buildStatusBadge(active, isRegister),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                        onPressed: () => _confirmDeleteUser(
                          uid: data['uid'] ?? '',
                          documentId: filtered[index].id,
                          role: 'teacher',
                          name: name,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildDetailRow('NIP', nip, text),
                  _buildDetailRow('Jenis Kelamin', gender, text),
                  _buildDetailRow('Alamat', alamat, text),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Tab 3, 4, 5: Admin, TU, Officer (from users collection)
  Widget _buildRoleUsersTab(String role, Color bg, Color border, Color text, Color subtext) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('schoolId', isEqualTo: _schoolId)
          .where('role', isEqualTo: role)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        
        final filtered = docs.where((doc) {
          final name = (doc.data()['nama'] ?? '').toString().toLowerCase();
          final email = (doc.data()['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) return _buildEmptyPlaceholder(role.toUpperCase());

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final data = filtered[index].data();
            final name = data['nama'] ?? 'Tanpa Nama';
            final email = data['email'] ?? '-';
            final active = data['aktif'] ?? true;
            final createdAtVal = data['createdAt'] as Timestamp?;
            final dateStr = createdAtVal != null
                ? "${createdAtVal.toDate().day}-${createdAtVal.toDate().month}-${createdAtVal.toDate().year}"
                : '-';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: text),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (active ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                active ? 'Aktif' : 'Non-aktif',
                                style: TextStyle(
                                  color: active ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                        onPressed: () => _confirmDeleteUser(
                          uid: filtered[index].id,
                          documentId: filtered[index].id,
                          role: role,
                          name: name,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildDetailRow('Email', email, text),
                  _buildDetailRow('Terdaftar Sejak', dateStr, text),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(bool active, bool isRegister, {bool lulus = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lulus) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Lulus',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isRegister ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isRegister ? 'Terdaftar' : 'Belum Register',
            style: TextStyle(
              color: isRegister ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (active ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            active ? 'Aktif' : 'Non-aktif',
            style: TextStyle(
              color: active ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String role) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'Tidak ada data $role.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
