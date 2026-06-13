# SysMng School - Sistem Manajemen Sekolah Terintegrasi

[![Flutter Version](https://img.shields.io/badge/Flutter-%5E3.9.2-blue.svg?style=flat&logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-orange.svg?style=flat&logo=firebase)](https://firebase.google.com)
[![GetX](https://img.shields.io/badge/State%20Management-GetX%20%7C%20Riverpod-green.svg?style=flat)](https://pub.dev/packages/get)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey.svg?style=flat)](#)

Sistem Manajemen Sekolah (`sys_mng_school`) adalah aplikasi mobile berbasis Flutter yang dirancang untuk mendigitalisasi dan menyederhanakan administrasi sekolah. Aplikasi ini menerapkan arsitektur modular yang rapi, integrasi database Firebase secara *real-time*, dan mengadopsi tampilan modern **Dark Glassmorphism** untuk memberikan pengalaman pengguna yang premium dan interaktif.

---

## 🌟 Fitur Utama Berdasarkan Peran (Role)

Aplikasi ini mendukung 4 peran pengguna utama dengan aksesibilitas yang telah disesuaikan:

### 1. Super Admin
*   **Pendaftaran Sekolah Baru:** Mendaftarkan sekolah ke dalam sistem menggunakan domain khusus sekolah (contoh: `smagamjk`).
*   **Pembuatan Kode Admin:** Menghasilkan kode admin (`kodeAdmin`) unik untuk masing-masing sekolah sebagai kunci autentikasi awal.
*   **Manajemen Aktivasi:** Mengaktifkan atau menonaktifkan sekolah dan paket langganan mereka.

### 2. Admin Sekolah (School Admin)
*   **Dashboard Statistik Premium:** Menampilkan ringkasan jumlah guru, murid, mata pelajaran, kelas, serta statistik absensi harian secara visual.
*   **Manajemen Guru:**
    *   Menambah data guru baru (NIP, Nama, Email).
    *   Mengatur mata pelajaran yang diajarkan oleh masing-masing guru.
    *   Melihat profil detail guru dan menonaktifkan/mengaktifkan status guru.
*   **Manajemen Murid:**
    *   Menambah murid baru (NIS, Nama, Email).
    *   Melihat profil lengkap murid serta kelas yang ditempati.
*   **Manajemen Kelas:**
    *   Membuat kelas baru dan menentukan Wali Kelas.
    *   Memasukkan murid ke dalam kelas secara terorganisir.
*   **Manajemen Mata Pelajaran:** Menambah, melihat, dan menyelaraskan daftar mata pelajaran sekolah.
*   **Manajemen Jadwal Pelajaran:** Mengatur jadwal mengajar guru dan jadwal kelas (Hari Senin - Sabtu).
*   **Pusat Komunikasi (Notifikasi):**
    *   Membuat dan menyebarkan notifikasi/pengumuman.
    *   Mendukung pengiriman filter multi-target: **Semua (Global)**, **Per Kelas**, **Per Guru**, atau **Per Murid**.
*   **Pengaturan Sekolah:** Mengubah logo sekolah, informasi profil sekolah, serta melakukan pembaruan password.

### 3. Guru (Teacher)
*   **Dashboard Personal Guru:** Akses instan ke jadwal mengajar hari ini dan status wali kelas.
*   **Jadwal Mengajar Terintegrasi:** Menampilkan semua jadwal mengajar guru di kelas manapun secara komprehensif.
*   **Sistem Absensi QR (QR Attendance):**
    *   Membuat sesi absensi dengan menghasilkan QR Code secara dinamis.
    *   Dilengkapi dengan pengaturan durasi kedaluwarsa sesi absensi untuk keamanan data presensi.
*   **Laporan Absensi (PDF Export):** Mengekspor rekapitulasi kehadiran murid dalam bentuk file PDF formal yang siap dicetak.
*   **Catatan Perilaku Siswa (Behavior Records):**
    *   Mencatat pelanggaran atau prestasi siswa secara instan.
    *   Dilengkapi fitur *swipe-to-delete* untuk menghapus catatan.
    *   Sistem pembersihan otomatis (*auto-cleanup*) yang menghapus data riwayat catatan perilaku setelah 24 jam.
*   **Kotak Masuk Notifikasi:** Menerima pengumuman global maupun pengumuman khusus untuk wali kelas / kelas yang diampu.

### 4. Murid (Student)
*   **Dashboard Murid:** Menampilkan ringkasan kehadiran hari ini, jadwal pelajaran terdekat, dan notifikasi terbaru.
*   **Scan QR Absensi:** Melakukan presensi masuk kelas secara instan dengan memindai QR Code yang ditunjukkan oleh guru pengampu (terintegrasi dengan validasi waktu aktif).
*   **Riwayat Kehadiran:** Memantau persentase dan daftar kehadiran harian (Hadir, Sakit, Izin, Alfa).
*   **Jadwal Pelajaran Kelas:** Menampilkan jadwal pelajaran lengkap untuk kelas yang sedang ditempuh murid.
*   **Penerimaan Notifikasi Personal:** Menerima notifikasi publik, notifikasi tingkat kelas, atau pengumuman khusus dari guru/admin yang ditujukan ke murid tersebut.

---

## 🎨 Sistem Desain & Estetika Premium

Aplikasi ini menggunakan tema **Dark Glassmorphic** yang konsisten dengan standar estetika modern:
*   **Glassmorphic Cards:** Menggunakan warna transparan `Colors.white.withValues(alpha: 0.06)` yang dipadukan dengan border tipis `alpha: 0.10` dan efek blur latar belakang (*backdrop filter*) untuk memberikan kesan premium.
*   **Latar Belakang Dinamis:** Menggunakan widget `AuthBackground` yang memberikan sentuhan gradasi warna ungu tua/biru dongker yang elegan.
*   **Aksen Warna Modul:**
    *   🟣 **Ungu (Purple):** Digunakan untuk modul dan navigasi Guru (Teachers).
    *   🔵 **Biru (Blue):** Digunakan untuk modul dan navigasi Murid (Students).
    *   🟢 **Hijau (Green):** Digunakan untuk modul Mata Pelajaran (Subjects).
    *   🟡 **Amber/Oranye:** Digunakan untuk modul Kelas (Classes).
    *   🌸 **Pink:** Digunakan untuk modul Jadwal (Schedules).
*   **Desain Dialog Responsif:** Semua kotak dialog menggunakan warna latar `Color(0xFF0F0C20)` dengan sudut melengkung `BorderRadius.circular(20)` dan garis tepi halus agar terlihat modern.

---

## 📁 Struktur Proyek (Folder Structure)

Aplikasi dirancang dengan pendekatan modular yang bersih:

```text
lib/
├── app/
│   └── routes/                  # Konfigurasi Navigasi GetX (routes & pages)
├── core/
│   ├── firebase/                # Konfigurasi inisialisasi Firebase
│   ├── models/                  # Objek model data (User, School, Teacher, dll)
│   ├── services/                # Layanan sistem (SessionService, AuthService, dll)
│   └── utils/                   # Fungsi utilitas (Format tanggal, PDF Helper, dll)
├── features/
│   ├── attendance/              # Logika absensi & validasi QR
│   ├── authentication/          # Fitur login, register, dan background dekoratif
│   ├── classes/                 # Halaman & logika manajemen kelas sekolah
│   ├── grades/                  # Pengaturan nilai siswa
│   ├── parents/                 # Manajemen wali murid (ekstensi masa depan)
│   ├── schools/                 # Panel admin sekolah & fitur pengaturannya
│   │   └── pages/
│   │       ├── classes/         # Halaman admin kelas & info kelas
│   │       ├── dashboard/       # Dashboard admin & menu fitur premium
│   │       ├── notifications/   # Pembuatan notifikasi multi-target
│   │       ├── schedule/        # Pengaturan jadwal mingguan (Senin - Sabtu)
│   │       ├── settings/        # Pengaturan profil & password sekolah
│   │       ├── students/        # List & detail murid untuk admin
│   │       ├── subjects/        # List & tambah mata pelajaran
│   │       └── teachers/        # List, detail & penugasan mata pelajaran guru
│   ├── splash/                  # Halaman inisialisasi awal aplikasi
│   ├── students/                # Dashboard & fitur absensi QR scanner murid
│   ├── subscriptions/           # Manajemen billing sekolah
│   ├── super_admin/             # Halaman registrasi sekolah baru
│   ├── teachers/                # Dashboard, QR generator, dan catatan perilaku guru
│   └── users/                   # Profil & pengaturan pengguna umum
├── firebase_options.dart        # Hasil konfigurasi Firebase CLI
└── main.dart                    # Entry point aplikasi Flutter
```

---

## 🗄️ Skema Database Cloud Firestore

Sistem menggunakan database Firestore non-relasional dengan relasi dokumen terstruktur sebagai berikut:

### 1. Koleksi `schools`
Menyimpan informasi sekolah yang terdaftar. Dokumen ID menggunakan nama domain sekolah agar mudah divalidasi.
```json
schools/ {domain} (e.g. schools/smagamjk)
{
  "schoolId": "String (UID unik)",
  "namaSekolah": "String",
  "domain": "String (e.g. smagamjk)",
  "kodeAdmin": "String (Kode autentikasi sekolah)",
  "aktif": "Boolean",
  "package": "String (e.g. trial, premium)",
  "createdAt": "Timestamp"
}
```

### 2. Koleksi `users`
Menyimpan data akun pengguna Firebase Authentication beserta peran (*role*) mereka.
```json
users/ {uid}
{
  "email": "String",
  "role": "String (super_admin | school_admin | teacher | student | parent)",
  "schoolId": "String (ID Sekolah relasi)",
  "aktif": "Boolean",
  "createdAt": "Timestamp"
}
```

### 3. Koleksi `teachers`
Menyimpan data profil lengkap guru.
```json
teachers/ {teacherId}
{
  "teacherId": "String",
  "schoolId": "String",
  "uid": "String (UID Firebase Auth jika sudah register)",
  "nip": "String",
  "nama": "String",
  "email": "String",
  "aktif": "Boolean",
  "sudahRegister": "Boolean",
  "createdAt": "Timestamp"
}
```

### 4. Koleksi `students`
Menyimpan data profil lengkap murid.
```json
students/ {studentId}
{
  "studentId": "String",
  "schoolId": "String",
  "uid": "String (UID Firebase Auth jika sudah register)",
  "nis": "String",
  "nama": "String",
  "aktif": "Boolean",
  "sudahRegister": "Boolean",
  "createdAt": "Timestamp"
}
```

---

## 🛠️ Panduan Instalasi & Konfigurasi

Ikuti langkah-langkah berikut untuk menjalankan aplikasi di lingkungan lokal Anda:

### Prasyarat
*   **Flutter SDK:** Versi `^3.9.2` atau lebih baru.
*   **Dart SDK:** Versi pendukung Flutter.
*   **Firebase CLI & Node.js:** Untuk melakukan inisialisasi konfigurasi proyek Firebase.
*   **Android Studio / Xcode:** Emulator atau perangkat fisik Android/iOS.

### Langkah Inisialisasi
1.  **Clone Repositori:**
    ```bash
    git clone https://github.com/fadhlysyahputra02/sys-mng-sch.git
    cd sys_mng_school
    ```

2.  **Ambil Dependensi Proyek:**
    ```bash
    flutter pub get
    ```

3.  **Konfigurasi Firebase:**
    Pastikan Anda sudah menginstal Firebase CLI, lalu jalankan perintah konfigurasi untuk menghubungkan proyek Anda dengan Firebase Console Anda:
    ```bash
    flutterfire configure
    ```
    Perintah ini akan memperbarui file `lib/firebase_options.dart` secara otomatis untuk mendukung platform target Anda (Android/iOS/Web).

4.  **Jalankan Aplikasi:**
    *   Menggunakan VS Code atau Android Studio: Buka proyek dan tekan tombol Run/Debug.
    *   Menggunakan Terminal:
        ```bash
        flutter run
        ```

---

## 📦 Paket Dependensi Penting (`pubspec.yaml`)

Berikut adalah daftar pustaka utama pihak ketiga yang digunakan dalam aplikasi ini beserta fungsinya:

| Paket Dependensi | Versi | Kegunaan |
| :--- | :--- | :--- |
| `firebase_core` | `^4.10.0` | Inisialisasi utama Firebase dalam aplikasi Flutter. |
| `firebase_auth` | `^6.5.2` | Autentikasi pengguna berbasis email, password, dan manajemen sesi masuk. |
| `cloud_firestore` | `^6.5.0` | Sinkronisasi data real-time dan penyimpanan data terstruktur sekolah. |
| `get` | `^4.7.3` | Manajemen rute (routing) GetX serta kemudahan navigasi antar halaman. |
| `flutter_riverpod` | `^3.3.1` | Manajemen state terdesentralisasi yang responsif dan aman. |
| `image_picker` | `^1.2.2` | Mengambil berkas logo sekolah dari galeri atau kamera perangkat. |
| `qr_flutter` | `^4.1.0` | Render dinamis QR Code untuk sesi absensi guru. |
| `mobile_scanner` | `^7.0.1` | Scanner barcode & QR Code performa tinggi untuk murid mengambil kehadiran. |
| `pdf` & `printing` | `^3.10.8` / `^5.11.1` | Pembuatan berkas dokumen PDF dan integrasi cetak laporan absensi murid. |
| `cupertino_icons` | `^1.0.8` | Penyediaan ikon gaya iOS yang konsisten. |

---

## 📄 Lisensi

Proyek ini dibuat untuk penggunaan internal manajemen sekolah. Seluruh hak cipta dilindungi oleh pengembang dan sekolah terafiliasi.
