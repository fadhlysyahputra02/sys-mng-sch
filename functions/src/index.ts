import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

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
      topics = [`school_${schoolId}_class_${targetId}`];
    } else if (targetType === "guru") {
      // Kirim ke semua guru di sekolah ini
      topics = [`school_${schoolId}_role_teacher`];
    } else if (targetType === "murid") {
      // Kirim ke topic kelas dari murid tersebut
      const classId = targetClassId || targetId;
      topics = [`school_${schoolId}_class_${classId}`];
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
