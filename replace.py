import re

with open('lib/features/schools/pages/teachers/pages/teacher_detail_admin_page.dart', 'r') as f:
    content = f.read()

helpers = """
  Widget _buildDetailSection(String title, IconData icon, List<Widget> children, Color textColor, Color borderColor, Color bgColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF6366F1)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.black12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, Color textColor, Color subTextColor) {
    final displayValue = (value == null || value.trim().isEmpty) ? '-' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              displayValue,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResetPassword"""

content = content.replace("  Future<void> _handleResetPassword", helpers)


profile_card_old = """                        // ── Profile Card ─────────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row("""

profile_card_new = """                        // ── Profile Card ─────────────────────────────────────
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                // Decoration circles
                                Positioned(
                                  top: -40,
                                  right: -20,
                                  child: Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -30,
                                  right: 60,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                                // Content
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row("""

content = content.replace(profile_card_old, profile_card_new)

# Fix the end of the profile card
profile_end_old = """                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),"""

profile_end_new = """                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),"""

# Wait, let's use regex to replace the end of the Profile Card.
import re

pattern = re.compile(r"(\s+)\]\,\n(\s+)\),\n(\s+)\]\,\n(\s+)\),\n(\s+)\]\,\n(\s+)\),\n(\s+)\),\n(\s+)const SizedBox\(height: 28\),")
# We need to insert the Stack and ClipRRect closing tags
replacement = r"\1],\n\2),\n\3],\n\4),\n\5],\n\6),\n\7),\n\7  ],\n\7),\n\7),\n\8const SizedBox(height: 28),"

content = pattern.sub(replacement, content)


# Now add the Informasi Lengkap block
info_block = """
                        const SizedBox(height: 24),

                        // ── Informasi Lengkap Guru ───────────────────────────
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.person_search_rounded, color: Color(0xFF6366F1), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Informasi Lengkap',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _buildDetailSection(
                          'Data Pribadi',
                          Icons.person_outline_rounded,
                          [
                            _buildInfoRow('Nama Lengkap', teacher['nama'], textColor, subTextColor),
                            _buildInfoRow('NIP', teacher['nip'], textColor, subTextColor),
                            _buildInfoRow('NUPTK', teacher['nuptk'], textColor, subTextColor),
                            _buildInfoRow('No. Pegawai', teacher['noPegawai'], textColor, subTextColor),
                            _buildInfoRow('Gelar Depan', teacher['gelarDepan'], textColor, subTextColor),
                            _buildInfoRow('Gelar Belakang', teacher['gelarBelakang'], textColor, subTextColor),
                            _buildInfoRow('Jenis Kelamin', teacher['gender'], textColor, subTextColor),
                            _buildInfoRow('Tempat Lahir', teacher['tempatLahir'], textColor, subTextColor),
                            _buildInfoRow('Tanggal Lahir', teacher['tanggalLahir'], textColor, subTextColor),
                            _buildInfoRow('Agama', teacher['agama'], textColor, subTextColor),
                            _buildInfoRow('Status Nikah', teacher['statusPernikahan'], textColor, subTextColor),
                            _buildInfoRow('Kewarganegaraan', teacher['kewarganegaraan'], textColor, subTextColor),
                            _buildInfoRow('Gol. Darah', teacher['golonganDarah'], textColor, subTextColor),
                            _buildInfoRow('Alamat', teacher['alamat'], textColor, subTextColor),
                            _buildInfoRow('No. HP', teacher['noHp'], textColor, subTextColor),
                            _buildInfoRow('Kontak Darurat', teacher['kontakDarurat'], textColor, subTextColor),
                          ],
                          textColor,
                          borderColor,
                          cardBgColor,
                        ),

                        _buildDetailSection(
                          'Data Identitas',
                          Icons.badge_outlined,
                          [
                            _buildInfoRow('NIK', teacher['nik'], textColor, subTextColor),
                            _buildInfoRow('NPWP', teacher['npwp'], textColor, subTextColor),
                            _buildInfoRow('BPJS Kesehatan', teacher['bpjsKesehatan'], textColor, subTextColor),
                            _buildInfoRow('BPJS Naker', teacher['bpjsKetenagakerjaan'], textColor, subTextColor),
                            _buildInfoRow('Nomor KK', teacher['nomorKk'], textColor, subTextColor),
                            _buildInfoRow('No. Rekening', teacher['nomorRekening'], textColor, subTextColor),
                            _buildInfoRow('Nama Bank', teacher['namaBank'], textColor, subTextColor),
                          ],
                          textColor,
                          borderColor,
                          cardBgColor,
                        ),

                        _buildDetailSection(
                          'Data Kepegawaian',
                          Icons.work_outline_rounded,
                          [
                            _buildInfoRow('Status Guru', teacher['statusGuru'], textColor, subTextColor),
                            _buildInfoRow('Jabatan', teacher['jabatan'], textColor, subTextColor),
                            _buildInfoRow('Pangkat/Gol', teacher['pangkatGolongan'], textColor, subTextColor),
                            _buildInfoRow('TMT', teacher['tmt'], textColor, subTextColor),
                            _buildInfoRow('Tgl Bergabung', teacher['tanggalBergabung'], textColor, subTextColor),
                            _buildInfoRow('Masa Kerja', teacher['masaKerja'], textColor, subTextColor),
                          ],
                          textColor,
                          borderColor,
                          cardBgColor,
                        ),

                        _buildDetailSection(
                          'Data Akademik',
                          Icons.school_outlined,
                          [
                            _buildInfoRow('Pend. Terakhir', teacher['pendidikanTerakhir'], textColor, subTextColor),
                            _buildInfoRow('Jurusan', teacher['jurusan'], textColor, subTextColor),
                            _buildInfoRow('Universitas', teacher['universitas'], textColor, subTextColor),
                            _buildInfoRow('Tahun Lulus', teacher['tahunLulus'], textColor, subTextColor),
                            _buildInfoRow('Sertifikasi', teacher['sertifikasiGuru'], textColor, subTextColor),
                            _buildInfoRow('Bid. Sertifikasi', teacher['bidangSertifikasi'], textColor, subTextColor),
                          ],
                          textColor,
                          borderColor,
                          cardBgColor,
                        ),

                        const SizedBox(height: 12),"""

content = content.replace("                        // ── Lihat Riwayat Absensi Button ──────────────────────────", info_block + "\n                        // ── Lihat Riwayat Absensi Button ──────────────────────────")

with open('lib/features/schools/pages/teachers/pages/teacher_detail_admin_page.dart', 'w') as f:
    f.write(content)

