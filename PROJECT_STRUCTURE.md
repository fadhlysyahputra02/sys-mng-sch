# SYS MNG SCHOOL - PROJECT STRUCTURE

## Teknologi

* Flutter
* Firebase Authentication
* Cloud Firestore
* Riverpod

---

# Role

1. super_admin
2. school_admin
3. teacher
4. student
5. parent

---

# Authentication

Firebase Auth digunakan untuk:

* super_admin
* school_admin
* teacher
* student
* parent

Setelah login:

Firebase Auth
↓
users/{uid}
↓
cek role
↓
redirect dashboard

---

# Firestore Structure

users
└── {uid}
├── email
├── role
├── schoolId
├── aktif
└── createdAt

schools
└── {domain}
├── schoolId
├── namaSekolah
├── domain
├── kodeAdmin
├── aktif
└── createdAt

```
  teachers
   └── {teacherId}
        ├── nip
        ├── nama
        ├── aktif
        ├── sudahRegister
        └── createdAt

  students
   └── {studentId}
        ├── nis
        ├── nama
        ├── aktif
        ├── sudahRegister
        └── createdAt

  classes
   └── {classId}

  attendance
   └── {attendanceId}

  grades
   └── {gradeId}
```

---

# Folder Structure

lib/

app/
├── routes
├── theme
└── constants

core/
├── firebase
├── services
├── utils
└── models

features/

authentication/
├── data
├── providers
├── pages
└── widgets

schools/
├── data
├── providers
└── pages

users/
├── data
├── providers
└── pages

students/
├── data
├── providers
├── pages
└── widgets

teachers/
├── data
├── providers
├── pages
└── widgets

parents/
├── data
├── providers
├── pages
└── widgets

classes/
├── data
├── providers
├── pages
└── widgets

attendance/
├── data
├── providers
├── pages
└── widgets

grades/
├── data
├── providers
├── pages
└── widgets

subscriptions/
├── data
├── providers
└── pages

---

# Alur Pendaftaran Sekolah

Super Admin
↓
Register School
↓
Generate kodeAdmin
↓
Firestore schools/{domain}

---

# Alur Register Admin Sekolah

Domain
↓
Validasi schools/{domain}
↓
Validasi kodeAdmin
↓
Firebase Auth Create User
↓
users/{uid}
↓
role = school_admin

---

# Catatan Penting

Document ID sekolah menggunakan:

schools/{domain}

Contoh:

schools/smagamjk

Bukan:

schools/{schoolId}
