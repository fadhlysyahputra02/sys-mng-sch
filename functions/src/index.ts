import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import * as nodemailer from "nodemailer";

initializeApp();

/**
 * Triggered setiap kali dokumen baru dibuat di:
 * /schools/{schoolId}/notifications/{notifId}
 *
 * Mengirim FCM Push Notification ke topic yang sesuai
 * berdasarkan targetType dari dokumen notifikasi.
 */
export const onNotificationCreated = onDocumentCreated(
  "schools/{schoolId}/notifications/{notifId}",
  async (event) => {
    const data = event.data?.data();
    const schoolId = event.params.schoolId;

    if (!data) {
      console.log("No data found in notification document.");
      return;
    }

    const title: string = data.title ?? "Notifikasi Baru";
    const body: string = data.content ?? "";
    const targetType: string = data.targetType ?? "umum";
    const targetId: string = data.targetId ?? "";
    const targetClassId: string = data.targetClassId ?? "";
    const senderId: string = data.senderId ?? "";
    const senderName: string = data.senderName ?? "Sistem";
    const senderRole: string = data.senderRole ?? "";
    const category: string = data.category ?? "";

    console.log(
      `[onNotificationCreated] schoolId=${schoolId}, targetType=${targetType}, ` +
      `targetId=${targetId}, senderId=${senderId}`
    );

    // --- Personal Notification ---
    if (targetType === "personal") {
      const db = getFirestore();
      const tokensSnap = await db
        .collection("users")
        .doc(targetId)
        .collection("tokens")
        .get();

      const tokens: string[] = [];
      tokensSnap.forEach((doc) => {
        const token = doc.data().token;
        if (token) tokens.push(token);
      });

      if (tokens.length === 0) {
        console.log(`No tokens found for user ${targetId}. Exiting.`);
        return;
      }

      const messaging = getMessaging();
      try {
        const response = await messaging.sendEachForMulticast({
          tokens: tokens,
          notification: {
            title: title,
            body: body,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              priority: "max",
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                alert: {
                  title: title,
                  body: body,
                },
                sound: "default",
                badge: 1,
                "content-available": 1,
              },
            },
          },
          data: {
            schoolId: schoolId,
            targetType: targetType,
            targetId: targetId,
            senderId: senderId,
            senderName: senderName,
            category: category,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        });
        console.log(`✅ FCM sent to ${tokens.length} tokens for user ${targetId}: successCount=${response.successCount}`);
      } catch (err) {
        console.error(`❌ Error sending personal FCM:`, err);
      }
      return;
    }

    // --- Tentukan Topic FCM berdasarkan targetType ---
    // Nama topic HARUS sama persis dengan yang didaftarkan di:
    // push_notification_service.dart -> registerUserDevice()
    let topics: string[] = [];

    if (targetType === "umum") {
      // Kirim ke semua user di sekolah ini
      topics = [`school_${schoolId}_umum`];
    } else if (targetType === "kelas") {
      // targetId = classId dari kelas yang dipilih
      if (senderRole === "parent") {
        // Jika dari orang tua, tujukan ke guru (pengajuan izin)
        topics = [`school_${schoolId}_class_${targetId}_teacher`];
      } else {
        // Jika dari guru/admin/TU, tujukan ke murid/orang tua di kelas tersebut
        topics = [`school_${schoolId}_class_${targetId}_student`];
      }
    } else if (targetType === "guru") {
      // Kirim ke semua guru di sekolah ini
      topics = [`school_${schoolId}_role_teacher`];
    } else if (targetType === "murid") {
      // Kirim ke topic kelas dari murid tersebut
      const classId = targetClassId || targetId;
      topics = [`school_${schoolId}_class_${classId}_student`];
    }

    if (topics.length === 0) {
      console.log("No topics determined. Exiting.");
      return;
    }

    const messaging = getMessaging();

    // Kirim ke setiap topic secara paralel
    const sendPromises = topics.map(async (topic) => {
      try {
        const messageId = await messaging.send({
          topic: topic,
          notification: {
            title: title,
            body: body,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              priority: "max",
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                alert: {
                  title: title,
                  body: body,
                },
                sound: "default",
                badge: 1,
                "content-available": 1,
              },
            },
          },
          data: {
            schoolId: schoolId,
            targetType: targetType,
            targetId: targetId,
            senderId: senderId,
            senderName: senderName,
            category: category,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        });
        console.log(`✅ FCM sent to topic [${topic}]: messageId=${messageId}`);
      } catch (err) {
        console.error(`❌ Error sending FCM to topic [${topic}]:`, err);
      }
    });

    await Promise.all(sendPromises);
    console.log("[onNotificationCreated] All FCM messages dispatched.");
  }
);

/**
 * Triggered setiap kali dokumen pengguna di hapus di:
 * /users/{userId}
 *
 * Menghapus akun autentikasi dari Firebase Auth.
 */
export const onUserDocumentDeleted = onDocumentDeleted(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    console.log(`[onUserDocumentDeleted] Memulai penghapusan auth untuk userId=${userId}`);
    try {
      await getAuth().deleteUser(userId);
      console.log(`✅ Berhasil menghapus pengguna dari Firebase Auth: userId=${userId}`);
    } catch (error: any) {
      if (error.code === "auth/user-not-found") {
        console.log(`ℹ️ Pengguna tidak ditemukan di Firebase Auth (mungkin sudah dihapus manual): userId=${userId}`);
      } else {
        console.error(`❌ Gagal menghapus pengguna dari Firebase Auth: userId=${userId}`, error);
      }
    }
  }
);

/**
 * Callable function to send a custom HTML reset password email
 * using Nodemailer and credentials stored in Firestore under /config/smtp.
 */
export const sendCustomResetPasswordEmail = onCall(async (request) => {
  const email = request.data?.email;
  if (!email) {
    throw new HttpsError("invalid-argument", "Email harus diisi.");
  }

  const db = getFirestore();
  const auth = getAuth();

  // 1. Ambil config SMTP dari Firestore
  const smtpSnap = await db.collection("config").doc("smtp").get();
  if (!smtpSnap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "SMTP belum dikonfigurasi di Firestore (/config/smtp)."
    );
  }

  const smtpData = smtpSnap.data();
  const host = smtpData?.host;
  const port = smtpData?.port;
  const secure = smtpData?.secure ?? true;
  const user = smtpData?.user;
  const pass = smtpData?.pass;
  const fromName = smtpData?.fromName ?? "Admin Sekolah";
  const fromEmail = smtpData?.fromEmail ?? user;
  const logoUrl = smtpData?.logoUrl ?? "https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=100&h=100&fit=crop";

  if (!host || !port || !user || !pass) {
    throw new HttpsError(
      "failed-precondition",
      "Konfigurasi SMTP tidak lengkap (host, port, user, pass harus diisi)."
    );
  }

  // 2. Generate reset password link dari Firebase Auth
  let link = "";
  let displayName = "Pengguna";
  try {
    const userRecord = await auth.getUserByEmail(email);
    displayName = userRecord.displayName ?? "Pengguna";
    link = await auth.generatePasswordResetLink(email);
  } catch (error: any) {
    console.error("Gagal generate link reset password:", error);
    if (error.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "Akun dengan email tersebut tidak ditemukan.");
    }
    throw new HttpsError("internal", "Gagal menghasilkan tautan reset password.");
  }

  // 3. Konfigurasi Transporter Nodemailer
  const transporter = nodemailer.createTransport({
    host: host,
    port: typeof port === "string" ? parseInt(port) : port,
    secure: secure,
    auth: {
      user: user,
      pass: pass,
    },
  });

  // 4. Siapkan template HTML
  const appName = "Sistem Informasi Sekolah";
  const htmlContent = `
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Password - ${appName}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f6f9fc; font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased;">
    <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed;">
        <tr>
            <td align="center" style="padding: 40px 0 20px 0;">
                <table border="0" cellpadding="0" cellspacing="0" width="600" style="max-width: 600px;">
                    <tr>
                        <td align="center" style="padding: 10px 0 20px 0;">
                            <img src="${logoUrl}" alt="Logo Sekolah" width="80" height="80" style="display: block; border: 0; outline: none; border-radius: 50%; object-fit: cover;" />
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
        <tr>
            <td align="center">
                <table border="0" cellpadding="0" cellspacing="0" width="600" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05); border: 1px solid #eef2f6; overflow: hidden;">
                    <tr>
                        <td height="6" style="background: linear-gradient(90deg, #6366f1, #8b5cf6);"></td>
                    </tr>
                    <tr>
                        <td style="padding: 40px 40px 30px 40px;">
                            <h1 style="margin: 0 0 20px 0; font-size: 24px; font-weight: 700; color: #1e1b4b; text-align: center;">Reset Kata Sandi Anda</h1>
                            <p style="margin: 0 0 20px 0; font-size: 16px; line-height: 1.6; color: #4b5563;">
                                Halo ${displayName},
                            </p>
                            <p style="margin: 0 0 30px 0; font-size: 16px; line-height: 1.6; color: #4b5563;">
                                Kami menerima permintaan untuk mengatur ulang kata sandi akun <strong>${appName}</strong> Anda untuk email <strong>${email}</strong>. Silakan klik tombol di bawah ini untuk membuat kata sandi baru:
                            </p>
                            <table border="0" cellpadding="0" cellspacing="0" width="100%">
                                <tr>
                                    <td align="center" style="padding: 0 0 30px 0;">
                                        <a href="${link}" target="_blank" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #6366f1, #8b5cf6); color: #ffffff; text-decoration: none; border-radius: 12px; font-weight: 600; font-size: 16px; box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);">Atur Ulang Kata Sandi</a>
                                    </td>
                                </tr>
                            </table>
                            <p style="margin: 0 0 20px 0; font-size: 14px; line-height: 1.6; color: #6b7280; text-align: center;">
                                Jika tombol di atas tidak berfungsi, Anda juga dapat menyalin dan menempelkan tautan berikut ke browser Anda:
                            </p>
                            <p style="margin: 0 0 30px 0; font-size: 12px; line-height: 1.5; color: #6366f1; text-align: center; word-break: break-all;">
                                <a href="${link}" target="_blank" style="color: #6366f1; text-decoration: underline;">${link}</a>
                            </p>
                            <hr style="border: 0; border-top: 1px solid #f3f4f6; margin: 30px 0;" />
                            <p style="margin: 0; font-size: 14px; line-height: 1.6; color: #9ca3af; text-align: center;">
                                Jika Anda tidak meminta untuk mereset kata sandi ini, silakan abaikan email ini dengan aman.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
        <tr>
            <td align="center" style="padding: 30px 0 40px 0;">
                <table border="0" cellpadding="0" cellspacing="0" width="600" style="max-width: 600px; text-align: center;">
                    <tr>
                        <td style="font-size: 12px; line-height: 1.5; color: #9ca3af;">
                            Email ini dikirim secara otomatis oleh sistem <strong>${appName}</strong>.<br>
                            &copy; 2026 Tim IT Sekolah. Hak Cipta Dilindungi.
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
  `;

  // 5. Kirim email
  try {
    await transporter.sendMail({
      from: `"${fromName}" <${fromEmail}>`,
      to: email,
      subject: `[ ${appName} ] Reset Kata Sandi Anda`,
      html: htmlContent,
    });
    return { success: true, message: "Email reset password telah dikirim." };
  } catch (error) {
    console.error("Gagal mengirim email reset password via SMTP:", error);
    throw new HttpsError("internal", "Gagal mengirim email reset password.");
  }
});
