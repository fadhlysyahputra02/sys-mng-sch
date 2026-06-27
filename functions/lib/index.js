"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserDocumentDeleted = exports.onNotificationCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const app_1 = require("firebase-admin/app");
const messaging_1 = require("firebase-admin/messaging");
const auth_1 = require("firebase-admin/auth");
(0, app_1.initializeApp)();
/**
 * Triggered setiap kali dokumen baru dibuat di:
 * /schools/{schoolId}/notifications/{notifId}
 *
 * Mengirim FCM Push Notification ke topic yang sesuai
 * berdasarkan targetType dari dokumen notifikasi.
 */
exports.onNotificationCreated = (0, firestore_1.onDocumentCreated)("schools/{schoolId}/notifications/{notifId}", async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    const schoolId = event.params.schoolId;
    if (!data) {
        console.log("No data found in notification document.");
        return;
    }
    const title = (_b = data.title) !== null && _b !== void 0 ? _b : "Notifikasi Baru";
    const body = (_c = data.content) !== null && _c !== void 0 ? _c : "";
    const targetType = (_d = data.targetType) !== null && _d !== void 0 ? _d : "umum";
    const targetId = (_e = data.targetId) !== null && _e !== void 0 ? _e : "";
    const targetClassId = (_f = data.targetClassId) !== null && _f !== void 0 ? _f : "";
    const senderId = (_g = data.senderId) !== null && _g !== void 0 ? _g : "";
    const senderName = (_h = data.senderName) !== null && _h !== void 0 ? _h : "Sistem";
    console.log(`[onNotificationCreated] schoolId=${schoolId}, targetType=${targetType}, ` +
        `targetId=${targetId}, senderId=${senderId}`);
    // --- Tentukan Topic FCM berdasarkan targetType ---
    // Nama topic HARUS sama persis dengan yang didaftarkan di:
    // push_notification_service.dart -> registerUserDevice()
    let topics = [];
    if (targetType === "umum") {
        // Kirim ke semua user di sekolah ini
        topics = [`school_${schoolId}_umum`];
    }
    else if (targetType === "kelas") {
        // targetId = classId dari kelas yang dipilih
        topics = [`school_${schoolId}_class_${targetId}`];
    }
    else if (targetType === "guru") {
        // Kirim ke semua guru di sekolah ini
        topics = [`school_${schoolId}_role_teacher`];
    }
    else if (targetType === "murid") {
        // Kirim ke topic kelas dari murid tersebut
        const classId = targetClassId || targetId;
        topics = [`school_${schoolId}_class_${classId}`];
    }
    if (topics.length === 0) {
        console.log("No topics determined. Exiting.");
        return;
    }
    const messaging = (0, messaging_1.getMessaging)();
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
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
            });
            console.log(`✅ FCM sent to topic [${topic}]: messageId=${messageId}`);
        }
        catch (err) {
            console.error(`❌ Error sending FCM to topic [${topic}]:`, err);
        }
    });
    await Promise.all(sendPromises);
    console.log("[onNotificationCreated] All FCM messages dispatched.");
});
/**
 * Triggered setiap kali dokumen pengguna di hapus di:
 * /users/{userId}
 *
 * Menghapus akun autentikasi dari Firebase Auth.
 */
exports.onUserDocumentDeleted = (0, firestore_1.onDocumentDeleted)("users/{userId}", async (event) => {
    const userId = event.params.userId;
    console.log(`[onUserDocumentDeleted] Memulai penghapusan auth untuk userId=${userId}`);
    try {
        await (0, auth_1.getAuth)().deleteUser(userId);
        console.log(`✅ Berhasil menghapus pengguna dari Firebase Auth: userId=${userId}`);
    }
    catch (error) {
        if (error.code === "auth/user-not-found") {
            console.log(`ℹ️ Pengguna tidak ditemukan di Firebase Auth (mungkin sudah dihapus manual): userId=${userId}`);
        }
        else {
            console.error(`❌ Gagal menghapus pengguna dari Firebase Auth: userId=${userId}`, error);
        }
    }
});
//# sourceMappingURL=index.js.map