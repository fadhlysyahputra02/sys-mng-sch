const admin = require('firebase-admin');

// Inisialisasi Firebase Admin dengan default credentials
// (Ini akan bekerja karena kita menjalankannya di dalam folder proyek Firebase yang sudah login)
admin.initializeApp();

const db = admin.firestore();

async function setSmtpConfig() {
  try {
    console.log('Menyimpan konfigurasi SMTP ke Firestore...');
    await db.collection('config').doc('smtp').set({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true,
      user: 'fadhly.syahputra@gmail.com',
      pass: 'qbdl luoh ojmu tuep',
      fromName: 'Admin SYS MNG SCH',
      fromEmail: 'fadhly.syahputra@gmail.com',
      logoUrl: 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=100&h=100&fit=crop'
    });
    console.log('✅ Konfigurasi SMTP berhasil disimpan ke Firestore (/config/smtp).');
    process.exit(0);
  } catch (error) {
    console.error('❌ Gagal menyimpan konfigurasi SMTP:', error);
    process.exit(1);
  }
}

setSmtpConfig();
