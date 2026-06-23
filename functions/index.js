const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const storage = getStorage();

/**
 * Cloud Function: Send push notification when a new chat message is created.
 *
 * Triggers on: chats/{chatId}/messages/{messageId}
 *
 * For each member of the chat (except the sender):
 *   1. Look up their FCM tokens from users/{uid}/fcm_tokens
 *   2. Send a push notification with the message preview
 *   3. Include chat metadata in the data payload for navigation
 */
exports.onNewChatMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const messageData = snap.data();
    const chatId = event.params.chatId;
    const senderId = messageData.sender_id;

    if (!senderId) {
      console.log("No sender_id in message, skipping");
      return;
    }

    // Get chat document to find members and chat info
    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      console.log(`Chat ${chatId} not found`);
      return;
    }

    const chatData = chatDoc.data();
    const memberIds = chatData.member_ids || [];
    const chatType = chatData.type || "dm";

    // Get sender name for notification title
    let senderName = "Someone";
    try {
      const senderDoc = await db.collection("users").doc(senderId).get();
      if (senderDoc.exists) {
        senderName = senderDoc.data().name || senderDoc.data().display_name || "Someone";
      }
    } catch (e) {
      console.log(`Could not get sender name: ${e}`);
    }

    // Build notification content
    const title = chatType === "dm"
      ? senderName
      : `${chatData.title || "Group"} • ${senderName}`;

    let body = "";
    switch (messageData.type) {
      case "text":
        body = messageData.text || "";
        break;
      case "image":
        body = "📷 Photo";
        break;
      case "file":
        body = "📎 File";
        break;
      case "audio":
        body = "🎵 Voice message";
        break;
      case "video":
        body = "🎬 Video";
        break;
      default:
        body = "New message";
    }

    // Collect FCM tokens for all members except sender
    const tokens = [];
    for (const memberId of memberIds) {
      if (memberId === senderId) continue; // Don't notify sender

      try {
        const tokensSnap = await db
          .collection("users")
          .doc(memberId)
          .collection("fcm_tokens")
          .get();

        tokensSnap.forEach((tokenDoc) => {
          tokens.push({
            token: tokenDoc.id,
            uid: memberId,
          });
        });
      } catch (e) {
        console.log(`Could not get tokens for ${memberId}: ${e}`);
      }
    }

    if (tokens.length === 0) {
      console.log("No FCM tokens found for recipients");
      return;
    }

    console.log(`Sending to ${tokens.length} token(s) for chat ${chatId}`);

    // Build the chat title for the recipient
    // For DM, the title should be the sender's name
    const chatTitle = chatType === "dm" ? senderName : (chatData.title || "Chat");

    // Send notifications
    const messages = tokens.map((t) => ({
      token: t.token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "chat_message",
        category: "chat_message",
        chat_id: chatId,
        chat_title: chatTitle,
        chat_type: chatType,
        sender_id: senderId,
        sender_name: senderName,
        message_type: messageData.type || "text",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        ttl: 300000,
        notification: {
          channelId: "chat_messages",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            badge: 1,
            sound: "default",
            "mutable-content": 1,
            "content-available": 1,
          },
        },
      },
    }));

    // Send all notifications (handle failures gracefully)
    const results = await Promise.allSettled(
      messages.map((msg) => messaging.send(msg))
    );

    let successCount = 0;
    let failCount = 0;
    const tokensToRemove = [];

    results.forEach((result, index) => {
      if (result.status === "fulfilled") {
        successCount++;
      } else {
        failCount++;
        const error = result.reason;
        // Remove invalid tokens
        if (
          error?.code === "messaging/invalid-registration-token" ||
          error?.code === "messaging/registration-token-not-registered"
        ) {
          tokensToRemove.push(tokens[index]);
        }
      }
    });

    // Clean up invalid tokens
    if (tokensToRemove.length > 0) {
      const batch = db.batch();
      for (const t of tokensToRemove) {
        batch.delete(
          db.collection("users").doc(t.uid).collection("fcm_tokens").doc(t.token)
        );
      }
      await batch.commit();
      console.log(`Removed ${tokensToRemove.length} invalid token(s)`);
    }

    console.log(
      `Notifications sent: ${successCount} success, ${failCount} failed`
    );

    // ── Update all members' userChats timestamps ──────────────
    // This ensures the chat bubbles to the top of every member's chat list
    // when a new message is sent (especially important for group/role chats).
    try {
      const tsBatch = db.batch();
      for (const memberId of memberIds) {
        if (memberId === senderId) continue; // Sender already updated client-side
        tsBatch.set(
          db.collection("users").doc(memberId).collection("user_chats").doc(chatId),
          {
            updated_at: require("firebase-admin/firestore").FieldValue.serverTimestamp(),
            has_messages: true,
          },
          { merge: true }
        );
      }
      await tsBatch.commit();
      console.log(`Updated userChats timestamps for ${memberIds.length - 1} member(s)`);
    } catch (tsErr) {
      console.log(`Could not update member timestamps: ${tsErr}`);
    }
  }
);

/**
 * Resolve Firestore user document IDs (firebase_uid) from task assignee IDs.
 * Assignee IDs may contain:
 * - firebase uid (e.g. "odoo_123")
 * - numeric backend ids (e.g. "123")
 */
async function resolveRecipientUidsFromTaskIds(rawIds) {
  const ids = Array.from(new Set((rawIds || []).map((v) => `${v || ""}`.trim()).filter(Boolean)));
  const uids = new Set();

  for (const id of ids) {
    if (id.startsWith("odoo_")) {
      uids.add(id);
      const odooDoc = await db.collection("users").doc(id).get();
      if (odooDoc.exists) uids.add(odooDoc.id);
      continue;
    }

    if (/^\d+$/.test(id)) {
      const intId = Number.parseInt(id, 10);
      if (!Number.isNaN(intId)) {
        const [byOdoo, byUid, byEmployee, odooDoc] = await Promise.all([
          db.collection("users").where("odoo_user_id", "==", intId).limit(1).get(),
          db.collection("users").where("uid", "==", intId).limit(1).get(),
          db.collection("users").where("employee_id", "==", intId).limit(1).get(),
          db.collection("users").doc(`odoo_${intId}`).get(),
        ]);

        if (!byOdoo.empty) uids.add(byOdoo.docs[0].id);
        if (!byUid.empty) uids.add(byUid.docs[0].id);
        if (!byEmployee.empty) uids.add(byEmployee.docs[0].id);
        if (odooDoc.exists) uids.add(odooDoc.id);
        uids.add(`odoo_${intId}`);
      }
      continue;
    }

    // Fallback: treat unknown non-numeric IDs as firebase UIDs.
    uids.add(id);
  }

  return Array.from(uids);
}

/**
 * Cloud Function: Send push notification when a new task comment is created.
 *
 * Trigger path:
 * users/{ownerUid}/todos/{todoId}/comments/{commentId}
 *
 * Recipients:
 * - assigned members (and followers if present)
 * - excludes the comment sender
 */
exports.onNewTaskComment = onDocumentCreated(
  "users/{ownerUid}/todos/{todoId}/comments/{commentId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const { ownerUid, todoId } = event.params;
    const commentData = snap.data() || {};
    const senderId = `${commentData.author_id || ""}`.trim();
    const senderName = `${commentData.author_name || "Someone"}`.trim() || "Someone";

    if (!senderId) {
      console.log("[TaskComment] Missing author_id, skipping");
      return;
    }

    const todoDoc = await db.collection("users").doc(ownerUid).collection("todos").doc(todoId).get();
    if (!todoDoc.exists) {
      console.log(`[TaskComment] Todo not found: owner=${ownerUid}, todo=${todoId}`);
      return;
    }

    const todoData = todoDoc.data() || {};
    const taskTitle = `${todoData.title || "Task"}`;

    const assignedIds = Array.isArray(todoData.assigned_member_ids)
      ? todoData.assigned_member_ids
      : [];
    const followerIds = Array.isArray(todoData.follower_member_ids)
      ? todoData.follower_member_ids
      : [];

    const explicitRecipients = Array.isArray(todoData.recipient_firebase_uids)
      ? todoData.recipient_firebase_uids
          .map((v) => `${v || ""}`.trim())
          .filter(Boolean)
      : [];

    const recipientUidCandidates =
      explicitRecipients.length > 0
        ? explicitRecipients
        : await resolveRecipientUidsFromTaskIds([
            ...assignedIds,
            ...followerIds,
            ownerUid,
          ]);

    // Build sender aliases to make sure sender never receives their own push.
    const senderAliases = new Set([senderId]);
    if (senderId.startsWith("odoo_")) {
      const numeric = senderId.replace(/^odoo_/, "").trim();
      if (/^\d+$/.test(numeric)) senderAliases.add(numeric);
    } else if (/^\d+$/.test(senderId)) {
      senderAliases.add(`odoo_${senderId}`);
    }

    try {
      const senderDoc = await db.collection("users").doc(senderId).get();
      if (senderDoc.exists) {
        const senderUserData = senderDoc.data() || {};
        const odooUserId = `${senderUserData.odoo_user_id || ""}`.trim();
        const uid = `${senderUserData.uid || ""}`.trim();
        if (odooUserId) {
          senderAliases.add(odooUserId);
          senderAliases.add(`odoo_${odooUserId}`);
        }
        if (uid) {
          senderAliases.add(uid);
          senderAliases.add(`odoo_${uid}`);
        }
      }
    } catch (e) {
      console.log(`[TaskComment] Could not enrich sender aliases: ${e}`);
    }

    const recipientUids = recipientUidCandidates.filter((uid) => !senderAliases.has(uid));
    if (recipientUids.length === 0) {
      console.log("[TaskComment] No recipients after sender exclusion");
      return;
    }

    const bodyContent = `${commentData.content || "New message"}`.trim();
    const body = bodyContent.length > 120 ? `${bodyContent.slice(0, 120)}...` : bodyContent;
    const title = `💬 ${senderName} commented on \"${taskTitle}\"`;

    const tokenRows = [];
    for (const recipientUid of recipientUids) {
      try {
        const tokenSnap = await db
          .collection("users")
          .doc(recipientUid)
          .collection("fcm_tokens")
          .get();

        tokenSnap.forEach((doc) => {
          tokenRows.push({ token: doc.id, uid: recipientUid });
        });
      } catch (e) {
        console.log(`[TaskComment] Failed to read tokens for ${recipientUid}: ${e}`);
      }
    }

    if (tokenRows.length === 0) {
      console.log("[TaskComment] No FCM tokens found for recipients");
      return;
    }

    const messages = tokenRows.map((row) => ({
      token: row.token,
      notification: {
        title,
        body,
      },
      data: {
        type: "task_message",
        category: "task",
        task_id: todoId,
        task_title: taskTitle,
        owner_uid: ownerUid,
        sender_id: senderId,
        sender_name: senderName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        ttl: 300000,
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    }));

    const results = await Promise.allSettled(messages.map((msg) => messaging.send(msg)));

    let successCount = 0;
    let failCount = 0;
    const tokensToRemove = [];

    results.forEach((result, index) => {
      if (result.status === "fulfilled") {
        successCount++;
      } else {
        failCount++;
        const error = result.reason;
        if (
          error?.code === "messaging/invalid-registration-token" ||
          error?.code === "messaging/registration-token-not-registered"
        ) {
          tokensToRemove.push(tokenRows[index]);
        }
      }
    });

    if (tokensToRemove.length > 0) {
      const batch = db.batch();
      for (const t of tokensToRemove) {
        batch.delete(db.collection("users").doc(t.uid).collection("fcm_tokens").doc(t.token));
      }
      await batch.commit();
      console.log(`[TaskComment] Removed ${tokensToRemove.length} invalid token(s)`);
    }

    console.log(`[TaskComment] Sent notifications for todo=${todoId}: ${successCount} success, ${failCount} failed`);
  }
);

/**
 * Scheduled Cloud Function: Clean up expired unsigned signable documents.
 *
 * Runs every hour. Finds signable_doc messages where:
 *   - expires_at < now
 *   - sign_status != 'signed'
 * Then deletes the message doc and its PDF from Storage.
 */
exports.cleanupExpiredSignableDocs = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "UTC",
    retryCount: 1,
  },
  async (event) => {
    const now = new Date();
    console.log(`[Cleanup] Running expired signable doc cleanup at ${now.toISOString()}`);

    // Query all chats
    const chatsSnap = await db.collection("chats").get();
    let deletedCount = 0;
    let errorCount = 0;

    for (const chatDoc of chatsSnap.docs) {
      try {
        // Find expired, unsigned signable docs in this chat
        const messagesSnap = await chatDoc.ref
          .collection("messages")
          .where("type", "==", "signable_doc")
          .where("expires_at", "<", now)
          .get();

        for (const msgDoc of messagesSnap.docs) {
          const data = msgDoc.data();

          // Skip if already signed — signed docs stay forever
          if (data.sign_status === "signed") continue;

          try {
            // Delete PDF from Storage if path exists
            if (data.media_path) {
              try {
                await storage.bucket().file(data.media_path).delete();
                console.log(`[Cleanup] Deleted file: ${data.media_path}`);
              } catch (storageErr) {
                // File may already be gone, that's fine
                console.log(`[Cleanup] Could not delete file ${data.media_path}: ${storageErr.message}`);
              }
            }

            // Delete the message document
            await msgDoc.ref.delete();
            deletedCount++;
            console.log(`[Cleanup] Deleted expired doc message ${msgDoc.id} from chat ${chatDoc.id}`);
          } catch (delErr) {
            errorCount++;
            console.error(`[Cleanup] Error deleting message ${msgDoc.id}: ${delErr}`);
          }
        }
      } catch (chatErr) {
        errorCount++;
        console.error(`[Cleanup] Error processing chat ${chatDoc.id}: ${chatErr}`);
      }
    }

    console.log(`[Cleanup] Done. Deleted: ${deletedCount}, Errors: ${errorCount}`);
  }
);
