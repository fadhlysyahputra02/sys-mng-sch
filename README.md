# SysMng School - Sistem Manajemen Sekolah Terintegrasi

[![Flutter Version](https://img.shields.io/badge/Flutter-%5E3.9.2-blue.svg?style=flat&logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Functions-orange.svg?style=flat&logo=firebase)](https://firebase.google.com)
[![State Management](https://img.shields.io/badge/State%20Management-Riverpod%20%7C%20GetX-green.svg?style=flat)](#)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey.svg?style=flat)](#)

Sistem Manajemen Sekolah (`sys_mng_school`) adalah aplikasi mobile berbasis Flutter modern yang dirancang untuk mendigitalisasi, menyederhanakan, dan mengintegrasikan seluruh operasional serta administrasi sekolah. Aplikasi ini mengadopsi arsitektur modular terstruktur, integrasi database Firebase secara *real-time*, eksekusi *Cloud Functions v2*, serta menyajikan tampilan visual berstandar **Dark Glassmorphism** yang interaktif dan berestetika tinggi.

---

## 🌟 Fitur Utama Berdasarkan Peran (8 Roles)

Aplikasi ini mendukung **8 peran pengguna (*roles*)** dengan hak akses dan fitur terdedikasi:

```
                  ┌─────────────────────────────────────────┐
                  │            SYS MNG SCHOOL               │
                  └────────────────────┬────────────────────┘
                                       │
     ┌──────────┬──────────┬───────────┼───────────┬──────────┬──────────┬──────────┐
     │          │          │           │           │          │          │          │
┌────┴───┐ ┌────┴───┐ ┌────┴───┐ ┌─────┴────┐ ┌────┴───┐ ┌────┴───┐ ┌────┴───┐ ┌────┴───┐
│ Super  │ │ Admin  │ │  Guru  │ │  Murid   │ │  Wali  │ │Petugas │ │  Tata  │ │Pustaka-│
│ Admin  │ │Sekolah │ │Teacher │ │ Student  │ │ Murid  │ │ Piket  │ │ Usaha  │ │  wan   │
└────────┘ └────────┘ └────────┘ └──────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

### 1. 🛡️ Super Admin
*   **Pendaftaran & Aktivasi Sekolah:** Mendaftarkan sekolah baru ke dalam sistem dengan menggunakan sub-domain unik sekolah (contoh: `smagamjk`).
*   **Pengeluaran Kode Admin:** Menghasilkan `kodeAdmin` khusus sebagai kunci lisensi dan autentikasi awal pendaftaran Admin Sekolah.
*   **Manajemen Status & Langganan:** Mengaktifkan/menonaktifkan status operasional sekolah serta mengelola paket langganan (*trial*, *basic*, *premium*).

---

### 2. 🏛️ Admin Sekolah (School Admin)
*   **Dashboard Statistik & Analytics:** Menampilkan visualisasi ringkasan jumlah guru, murid, kelas, mata pelajaran, serta grafik absensi harian secara *real-time*.
*   **Manajemen Master Data Kompleks:**
    *   **Data Guru:** Registrasi NIP, Nama, Email, penugasan mata pelajaran, serta reset kredensial akun.
    *   **Data Murid:** Registrasi NIS, NISN, Nama, penetapan kelas, dan pengaturan status aktif.
    *   **Data Wali Murid:** Pengelolaan data orang tua/wali murid dan penautan dengan akun murid.
    *   **Data Kelas & Jurusan:** Pembuatan kelas, alokasi Wali Kelas, penentuan jurusan, dan pengelolaan daftar ruangan.
    *   **Data Mata Pelajaran & Tahun Ajaran:** Manajemen kurikulum dan penetapan tahun akademik aktif.
*   **Akademik & Matrix Schedule Generator:**
    *   Sistem generator jadwal otomatis mingguan (Senin - Sabtu).
    *   Penjadwalan bentrok-bebas antara ruang, guru, dan mata pelajaran.
    *   Laporan Jurnal KBM (Kegiatan Belajar Mengajar) dan rekap jam mengajar guru.
*   **Ujian & CBT Matrix Generator:**
    *   Membuat event ujian (UTS, UAS, Ujian Sekolah).
    *   Generator otomatis jadwal ujian, pembagian ruangan, dan alokasi sesi.
    *   Pencetakan Kartu Ujian murid dan penunjukan pengawas ujian.
*   **Pusat Pengaturan E-Rapor:**
    *   Konfigurasi bobot nilai (Formatik, Sumatif, UTS, UAS).
    *   Kustomisasi header/footer PDF E-Rapor, pasang watermark, logo sekolah, dan tanda tangan digital Kepala Sekolah.
*   **Pengawasan Operasional Pos Keuangan & Perpustakaan:** Monitoring umum kas sekolah, tagihan SPP, dan status peminjaman buku perpustakaan.
*   **Pusat Pengumuman Multi-Target (FCM Broadcast):**
    *   Membuat dan menyebarkan notifikasi push secara presisi.
    *   Dukungan filter target: **Semua Pengguna**, **Spesifik Per Kelas**, **Per Guru**, **Per Murid**, atau **Per Wali Murid**.
*   **Pengaturan Sekolah & Integrasi SMTP:** Mengubah logo sekolah, informasi kontak, profil sekolah, serta konfigurasi server SMTP Nodemailer untuk email reset password kustom.

---

### 3. 👨‍🏫 Guru (Teacher)
*   **Dashboard Personal Guru:** Akses cepat ke jadwal mengajar hari ini, status tugas wali kelas, serta *Wall of Class*.
*   **Sistem Absensi QR Dynamic & Checklist Manual:**
    *   **QR Generator Dynamic:** Membuat sesi absensi dengan QR Code berbatas waktu (*timer countdown*) untuk keamanan presensi.
    *   **Checklist Manual:** Pencatatan presensi siswa harian secara langsung per kelas.
    *   **Export Rekap Absensi:** Mencetak dan mengekspor rekapitulasi presensi murid ke format PDF & Excel.
*   **Bank Soal & Modul CBT Guru:**
    *   Pembuatan soal Pilihan Ganda & Esai beserta pilihan jawaban, kunci jawaban, dan bobot poin.
    *   Koreksi esai ujian murid dan pemberian nilai evaluasi secara fleksibel.
*   **Dashboard Pengawas Ujian (Proctor Dashboard):**
    *   Monitoring status ujian murid secara *real-time* (Belum mulai, Mengerjakan, Selesai).
    *   Kontrol pengawasan: Reset token ujian, *lock/unlock* sesi murid, perpanjangan durasi waktu, dan *force submit*.
*   **Manajemen Tugas & Pekerjaan Rumah (PR):**
    *   Membuat tugas kelas, melampirkan instruksi/deskripsi, dan menetapkan tanggal tenggat (*deadline*).
    *   Memeriksa jawaban murid (file/tautan) dan memberikan masukan serta nilai.
*   **Pengolahan Nilai & E-Rapor (Khusus Wali Kelas):**
    *   Input Nilai Harian, Nilai UTS, dan Nilai UAS.
    *   Pencatatan nilai ekstrakurikuler, kehadiran, serta catatan perkembangan karakter murid.
    *   Pratinjau (*preview*) dan pencetakan file PDF E-Rapor resmi murid.
*   **Persetujuan Surat Izin & Pelanggaran:**
    *   Persetujuan/penolakan permohonan izin atau sakit yang diajukan oleh wali murid.
    *   Pencatatan poin pelanggaran disiplin dan rekam prestasi siswa.
*   **Chat Real-Time:** Perpesanan instan dengan murid, wali murid, dan grup obrolan kelas.

---

### 4. 👨‍🎓 Murid (Student)
*   **Dashboard Personal Murid:** Menampilkan ringkasan persentase kehadiran, jadwal pelajaran hari ini, tenggat tugas terdekat, dan notifikasi terbaru.
*   **Scan QR Absensi Kelas:** Presensi masuk kelas secara praktis dengan memindai QR Code yang ditampilkan oleh guru pengampu.
*   **Kartu Identitas Digital (QR Student Identity):** Menampilkan QR Code ID Murid unik yang siap di-scan oleh Petugas Piket saat masuk atau keluar gerbang sekolah.
*   **Portal Ujian Online (CBT Student Portal):**
    *   Pengerjaan ujian online interaktif dengan *timer countdown*.
    *   Proteksi keamanan ujian (*auto-save* jawaban dan pengerjaan terisolasi).
    *   Pengiriman (*submit*) jawaban ujian otomatis saat waktu habis.
*   **Tugas & PR Online:** Memantau tugas aktif, mengunggah berkas/link jawaban, serta melihat status kelulusan dan nilai tugas.
*   **Riwayat Presensi & Nilai Akademik:** Memantau riwayat presensi harian (Hadir, Sakit, Izin, Alpa), nilai harian, nilai ujian, serta mengunduh E-Rapor PDF.
*   **Pautan Orang Tua (Parent Link):** Menghasilkan kode tautan unik untuk mengonfirmasi dan menghubungkan akun siswa dengan akun orang tua.
*   **Rincian SPP & Obrolan:** Memantau rincian status tagihan SPP dan berkomunikasi di grup kelas.

---

### 5. 👨‍👩‍👧 Wali Murid / Orang Tua (Parent)
*   **Dashboard Multi-Anak:** Pemantauan perkembangan seluruh anak yang bersekolah di instansi yang sama dalam satu tampilan terpadu.
*   **Monitoring Presensi Real-Time:** Notifikasi & rekapitulasi kehadiran anak setiap hari (termasuk jam masuk dan pulang di gerbang sekolah).
*   **Pengajuan Surat Izin & Sakit Online:** Mengajukan permohonan izin/sakit anak dilengkapi dengan unggahan foto surat keterangan dokter atau dokumen pendukung.
*   **Monitoring Akademik & E-Rapor:** Memantau perolehan nilai tugas, hasil ujian CBT, serta mengunduh berkas E-Rapor PDF anak secara langsung.
*   **Catatan Kedisiplinan & Pelanggaran:** Memantau rekam poin pelanggaran atau prestasi anak yang dicatat oleh pihak sekolah.
*   **Pembayaran SPP & Upload Bukti Transfer:** Melihat rincian tagihan SPP bulanan dan mengunggah foto bukti transaksi pembayaran ke unit Keuangan (TU).
*   **Chat Langsung dengan Guru:** Komunikasi dua arah langsung dengan Wali Kelas atau Guru Pengampu.

---

### 6. 👮‍♂️ Petugas Piket / Keamanan (Officer)
*   **Officer Dashboard:** Tampilan ringkas untuk akses cepat fitur utama pemindaian QR & rekapitulasi presensi harian.
*   **Gate QR Scanner (Presensi Gerbang):** Pemindaian QR Identitas Digital Murid & Guru di pintu gerbang sekolah untuk pencatatan jam kedatangan (*Check-in*) dan kepulangan (*Check-out*).
*   **Pencatatan Presensi Manual:** Fasilitas input kehadiran manual bagi murid/guru yang lupa membawa kartu atau mengalami kendala perangkat.
*   **Laporan & Rekapitulasi Presensi:** Rekap harian dan bulanan kehadiran gerbang sekolah yang dapat diekspor ke PDF.

---

### 7. 💳 Tata Usaha / Keuangan (TU)
*   **Dashboard Keuangan:** Ringkasan total penerimaan SPP, tunggakan siswa, dan neraca kas sekolah.
*   **Manajemen Tarif SPP & Biaya Sekolah:** Pengaturan besaran SPP per kelas/jurusan dan pembuat tagihan bulanan otomatis.
*   **Verifikasi & Konfirmasi Pembayaran:** Modul verifikasi pembayaran tunai di kasir TU maupun validasi unggahan bukti transfer dari wali murid/siswa.
*   **Cetak Kwitansi & Laporan Keuangan:** Pencetakan kwitansi formal pembayaran dan laporan rekapitulasi keuangan sekolah.

---

### 8. 📚 Pustakawan (Librarian)
*   **Dashboard Perpustakaan:** Ringkasan statistik sirkulasi buku, jumlah peminjaman aktif, peminjaman jatuh tempo, dan rekap denda.
*   **Katalog Buku & Inventaris:** Manajemen master data buku (Nomor ISBN, Judul, Pengarang, Penerbit, Stok Tersedia, dan Kategori Buku).
*   **Sirkulasi Peminjaman & Pengembalian:** Transaksi peminjaman dan pengembalian buku murid/guru yang dilengkapi dengan sistem kalkulasi denda keterlambatan otomatis.

---

## ⚡ Integrasi Firebase Cloud Functions v2 & Messaging

Sistem didukung oleh backend *Firebase Cloud Functions v2* (Node.js/TypeScript) yang menangani tugas otomatisasi background:

1.  **`onNotificationCreated`**
    *   *Trigger:* Pembuatan dokumen baru pada koleksi `/schools/{schoolId}/notifications/{notifId}`.
    *   *Fungsi:* Mengirimkan Push Notification berbasis **Firebase Cloud Messaging (FCM)** ke topik terdaftar (`school_{id}_umum`, `school_{id}_class_{id}`, role-specific topic) maupun pesan multicast personal ke perangkat target.
2.  **`onUserDocumentDeleted`**
    *   *Trigger:* Penghapusan dokumen pengguna pada koleksi `/users/{userId}`.
    *   *Fungsi:* Menghapus akun autentikasi dari **Firebase Auth** secara otomatis untuk menjamin konsistensi data.
3.  **`sendCustomResetPasswordEmail`**
    *   *Trigger:* *Callable Https Function*.
    *   *Fungsi:* Mengirimkan email reset password berbasis HTML dengan template modern via **Nodemailer SMTP** (menggunakan identitas, nama sekolah, dan logo sekolah secara dinamis).

---

## 🎨 Sistem Desain & Estetika Premium

Aplikasi ini mengusung estetika visual **Dark Glassmorphic** modern yang ramah mata dan responsif:
*   **Glassmorphic Cards:** Menggunakan latar transparan `Colors.white.withValues(alpha: 0.06)`, garis tepi tipis `alpha: 0.10`, serta efek blur (*backdrop filter*).
*   **Latar Belakang Dinamis:** Widget `AuthBackground` dengan gradasi warna ungu tua dan biru dongker yang elegan.
*   **Skema Warna Modul Terintegrasi:**
    *   🟣 **Ungu (Purple):** Modul & Navigasi Guru / Akademik.
    *   🔵 **Biru (Blue):** Modul & Navigasi Murid / CBT.
    *   🟢 **Hijau (Green):** Modul Keuangan (TU) & Mata Pelajaran.
    *   🟡 **Amber/Oranye:** Modul Kelas & Jadwal Ujian.
    *   🌸 **Pink:** Modul Wali Murid & Notifikasi.
    *   🔴 **Merah (Red):** Modul Pelanggaran & Poin Disiplin.

---

## 📁 Struktur Proyek (Folder Structure)

Arsitektur aplikasi dirancang modular berbasis fitur (*Feature-First Pattern*):

```text
lib/
├── app/
│   ├── constants/               # Konstanta aplikasi & warna tema
│   ├── routes/                  # Konfigurasi rute & navigasi GetX
│   └── theme/                   # Tema Dark Glassmorphism aplikasi
├── core/
│   ├── firebase/                # Konfigurasi inisialisasi Firebase
│   ├── models/                  # Data models (User, School, Teacher, Student, Class, Exam, Rapor, dll)
│   ├── services/                # Core business services (AuthService, SessionService, PushNotifService, dll)
│   └── utils/                   # Helper & utilitas (PDF Generator, Excel Helper, Date Formatter)
├── features/
│   ├── attendance/              # Logika absensi QR & presensi manual
│   ├── authentication/          # Fitur login, register, & background dekoratif
│   ├── chat/                    # Pesan real-time (Murid, Guru, Orang Tua, Grup Kelas)
│   ├── classes/                 # Manajemen data kelas & ruangan
│   ├── exams/                   # Engine Ujian CBT, Bank Soal, Proctor Dashboard, & Generator Matrix
│   ├── grades/                  # Pengolahan Nilai & Rekap Akademik
│   ├── librarian/               # Modul Perpustakaan & Sirkulasi Buku
│   ├── officer/                 # Modul Petugas Piket & Presensi Gerbang
│   ├── parent/ & parent_link/   # Portal Wali Murid, Pengajuan Izin, & Link Akun
│   ├── schools/                 # Panel Admin Sekolah, E-Rapor Engine, & Pengaturan Sekolah
│   ├── shared/                  # Reusable widgets (Glass Card, Custom Input, Loading States)
│   ├── splash/                  # Halaman inisialisasi splash screen
│   ├── students/                # Dashboard Murid, Portal CBT, Submisi Tugas, & QR Identitas
│   ├── subscriptions/           # Billing & Paket Langganan Sekolah
│   ├── super_admin/             # Registrasi Sekolah Baru & Lisensi
│   ├── tasks/                   # Engine Tugas & PR (Teacher & Student)
│   ├── teachers/                # Dashboard Guru, Generator QR Absensi, & Input Nilai Rapor
│   ├── tu/                      # Modul Tata Usaha (Tagihan SPP, Kas, & Laporan Keuangan)
│   └── users/                   # Manajemen profil pengguna
├── firebase_options.dart        # Konfigurasi Firebase CLI
└── main.dart                    # Entry point aplikasi Flutter
```

---

## 🗄️ Skema Database Cloud Firestore

Aplikasi menggunakan skema Cloud Firestore non-relasional terstruktur:

```
├── schools/ {domain}            # Dokumen identitas sekolah
├── users/ {uid}                 # Akun autentikasi & peranan pengguna
├── teachers/ {teacherId}        # Master profil data guru
├── students/ {studentId}        # Master profil data murid
├── classes/ {classId}           # Master data kelas & Wali Kelas
├── attendance/ {attendanceId}   # Riwayat presensi harian & QR Session
├── exams/ {examId}              # Event ujian, jadwal, & bank soal
├── grades/ {gradeId}            # Nilai Harian, UTS, UAS, & E-Rapor
├── tasks/ {taskId}              # Data tugas & unggahan jawaban murid
├── chats/ {chatRoomId}          # Ruang percakapan & riwayat pesan
├── tu_bills/ {billId}           # Data tagihan SPP & konfirmasi pembayaran
├── library_books/ {bookId}      # Katalog buku & transaksi peminjaman
├── permits/ {permitId}          # Permohonan surat izin/sakit murid
└── notifications/ {notifId}     # Dokumen pengumuman & trigger FCM
```

---

## 🛠️ Panduan Instalasi & Konfigurasi

### Prasyarat System
*   **Flutter SDK:** Versi `^3.9.2` atau lebih baru.
*   **Dart SDK:** Disesuaikan dengan Flutter SDK.
*   **Node.js & Firebase CLI:** Untuk deployment Firebase Cloud Functions.
*   **Android Studio / Xcode:** Emulator atau perangkat fisik Android/iOS.

### Langkah Instalasi
1.  **Clone Repositori:**
    ```bash
    git clone https://github.com/fadhlysyahputra02/sys-mng-sch.git
    cd sys_mng_school
    ```

2.  **Ambil Dependensi Flutter:**
    ```bash
    flutter pub get
    ```

3.  **Konfigurasi Firebase App:**
    ```bash
    flutterfire configure
    ```

4.  **Deploy Cloud Functions (Opsional untuk Fitur Push Notif & Custom Email):**
    ```bash
    cd functions
    npm install
    npm run build
    firebase deploy --only functions
    cd ..
    ```

5.  **Jalankan Aplikasi:**
    ```bash
    flutter run
    ```

---

## 📦 Paket Dependensi Utama (`pubspec.yaml`)

Berikut adalah daftar pustaka pihak ketiga utama yang digunakan beserta fungsinya:

| Paket Dependensi | Versi | Kegunaan |
| :--- | :--- | :--- |
| `firebase_core` | `^4.10.0` | Inisialisasi utama engine Firebase. |
| `firebase_auth` | `^6.5.2` | Manajemen autentikasi & sesi pengguna. |
| `cloud_firestore` | `^6.5.0` | Database *real-time* terstruktur. |
| `firebase_storage` | `^13.4.3` | Penyimpanan cloud logo, foto lampiran, & surat izin. |
| `cloud_functions` | `^6.3.5` | Integrasi pemanggilan Cloud Functions dari aplikasi. |
| `firebase_messaging` | `^16.3.0` | Penerimaan Push Notification FCM. |
| `flutter_local_notifications` | `^18.0.0` | Penanganan notifikasi lokal & *channel* notifikasi Android/iOS. |
| `flutter_riverpod` | `^3.3.1` | Management state reaktif & terdesentralisasi. |
| `get` | `^4.7.3` | Manajer rute navigasi aplikasi. |
| `qr_flutter` | `^4.1.0` | Render dinamis QR Code absensi & identitas digital. |
| `mobile_scanner` | `^7.0.1` | Scanner barcode & QR Code performa tinggi. |
| `pdf` & `printing` | `^3.10.8` / `^5.11.1` | Pembuatan & pencetakan berkas PDF (E-Rapor, Kartu Ujian, Rekap). |
| `excel` | `^4.0.6` | Export rekapitulasi data ke berkas spreadsheet Excel (.xlsx). |
| `image_picker` & `file_picker` | `^1.2.2` / `^11.0.2` | Pengambilan foto & pemilih dokumen lampiran tugas/izin. |
| `shared_preferences` | `^2.5.5` | Penyimpanan preferensi & sesi lokal perangkat. |
| `intl` | `^0.20.2` | Format tanggal, waktu, dan mata uang Rupiah (IDR). |

---

## 📄 Lisensi

Proyek ini dibuat untuk penggunaan internal dan pengelolaan sistem manajemen sekolah terintegrasi. Seluruh hak cipta dilindungi oleh pengembang dan instansi sekolah terafiliasi.
