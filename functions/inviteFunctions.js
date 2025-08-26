const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

const db = admin.firestore();

// Secret for HMAC signature generation (should match client-side)
const INVITE_SECRET = 'newport_invite_secret_2024';

/**
 * Generate HMAC signature for invite security
 */
function generateSignature(inviteId, expiresAt) {
  const message = `${inviteId}:${expiresAt}`;
  const hmac = crypto.createHmac('sha256', INVITE_SECRET);
  hmac.update(message);
  return hmac.digest('hex').substring(0, 16); // Short signature for URL
}

/**
 * Verify HMAC signature
 */
function verifySignature(inviteId, expiresAt, signature) {
  const expectedSignature = generateSignature(inviteId, expiresAt);
  return expectedSignature === signature;
}

/**
 * Cloud Function: Create family invite link
 * Callable from the app
 */
exports.createFamilyInvite = functions.https.onCall(async (data, context) => {
  try {
    // Ensure user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }

    const { apartmentIds } = data;
    
    if (!Array.isArray(apartmentIds) || apartmentIds.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'No apartments selected');
    }

    const inviterUid = context.auth.uid;
    console.log(`Creating family invite for user: ${inviterUid}, apartments: ${apartmentIds}`);

    // Validate user has access to these apartments
    const validApartmentIds = await validateUserApartments(inviterUid, apartmentIds);
    if (validApartmentIds.length === 0) {
      throw new functions.https.HttpsError('permission-denied', 'No valid apartments found');
    }

    // Get user info to determine role
    const userRole = await getUserRole(inviterUid);
    if (!['owner', 'renter'].includes(userRole)) {
      throw new functions.https.HttpsError('permission-denied', 'User does not have permission to create invitations');
    }

    // Create invitation document
    const expiresAt = Date.now() + (3600 * 1000); // 1 hour from now
    const inviteData = {
      inviterUid: inviterUid,
      inviterRole: userRole,
      apartmentIds: validApartmentIds,
      roleToGrant: 'family_full',
      expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt),
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      usedByUid: null,
      usedAt: null
    };

    const inviteRef = await db.collection('invitations').add(inviteData);
    const inviteId = inviteRef.id;

    // Generate signature with actual document ID
    const signature = generateSignature(inviteId, expiresAt);
    
    // Update document with signature
    await inviteRef.update({ inviteSignature: signature });

    // Generate invite URL
    const inviteUrl = `https://newport.app/invite/${inviteId}?sig=${signature}`;

    console.log(`Created invitation: ${inviteId} with ${validApartmentIds.length} apartments`);

    return {
      success: true,
      inviteId: inviteId,
      inviteUrl: inviteUrl,
      expiresAt: expiresAt,
      apartmentCount: validApartmentIds.length
    };

  } catch (error) {
    console.error('Error creating family invite:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Cloud Function: Accept family invite
 * Called after SMS phone authentication
 */
exports.acceptFamilyInvite = functions.https.onCall(async (data, context) => {
  try {
    // Ensure user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated via phone to accept invite');
    }

    const { inviteId, signature, name, phone, fcmToken } = data;
    const newUserUid = context.auth.uid;

    if (!inviteId || !name || !phone) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    console.log(`Accepting family invite: ${inviteId} by user: ${newUserUid}`);

    // Fetch the invitation document
    const inviteDoc = await db.collection('invitations').doc(inviteId).get();
    
    if (!inviteDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Invitation not found');
    }

    const invite = inviteDoc.data();

    // Check expiration and usage
    if (invite.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Invitation already used or revoked');
    }

    const now = Date.now();
    const expiresAt = invite.expiresAt.toMillis();
    
    if (now > expiresAt) {
      // Mark as expired
      await inviteDoc.ref.update({ status: 'expired' });
      throw new functions.https.HttpsError('failed-precondition', 'Invitation has expired');
    }

    // Verify signature if provided
    if (signature && invite.inviteSignature) {
      if (!verifySignature(inviteId, expiresAt, signature)) {
        throw new functions.https.HttpsError('permission-denied', 'Invalid invitation signature');
      }
    }

    // Begin transaction to ensure atomic updates
    await db.runTransaction(async (transaction) => {
      // 1. Create/update user profile in userProfiles collection (NOT users!)
      const userRef = db.collection('userProfiles').doc(newUserUid);
      const userData = {
        uid: newUserUid,
        fullName: name,
        phone: phone,
        role: 'family_full',
        invitedBy: invite.inviterUid,
        apartmentIds: invite.apartmentIds,
        fcmTokens: fcmToken ? [fcmToken] : [],
        lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        dataSource: 'cloud_function_invite',
      };
      
      transaction.set(userRef, userData, { merge: true });

      // 2. Update each apartment document: add new user to members and FCM token
      for (const apartmentId of invite.apartmentIds) {
        const apartmentRef = await findApartmentDocument(apartmentId);
        
        if (apartmentRef) {
          const updateData = {
            members: admin.firestore.FieldValue.arrayUnion({
              uid: newUserUid,
              role: 'family_full',
              name: name,
              addedAt: admin.firestore.FieldValue.serverTimestamp()
            })
          };

          // Add FCM token if provided
          if (fcmToken) {
            updateData.fcmTokens = admin.firestore.FieldValue.arrayUnion(fcmToken);
          }

          transaction.update(apartmentRef, updateData);
        }
      }

      // 3. Mark invitation as consumed
      transaction.update(inviteDoc.ref, {
        status: 'consumed',
        usedByUid: newUserUid,
        usedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    // 4. Send push notification to inviter
    await notifyInviterOfAcceptance(invite.inviterUid, name, invite.apartmentIds.length);

    console.log(`Family invite accepted successfully: ${inviteId} by ${name}`);

    return {
      success: true,
      message: 'Successfully joined family access',
      apartmentCount: invite.apartmentIds.length
    };

  } catch (error) {
    console.error('Error accepting family invite:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Validate that apartment IDs belong to the user
 */
async function validateUserApartments(userUid, apartmentIds) {
  try {
    const validIds = [];

    for (const apartmentId of apartmentIds) {
      // Find apartment document and check ownership
      const apartmentRef = await findApartmentDocument(apartmentId);
      
      if (apartmentRef) {
        const apartmentDoc = await apartmentRef.get();
        
        if (apartmentDoc.exists) {
          const data = apartmentDoc.data();
          
          // Check if user is owner/renter of this apartment
          const userIsOwner = data.passport_number === userUid || 
                             data.ownerId === userUid ||
                             data.uid === userUid;
          
          if (userIsOwner) {
            validIds.push(apartmentId);
          }
        }
      }
    }

    return validIds;
  } catch (error) {
    console.error('Error validating user apartments:', error);
    return [];
  }
}

/**
 * Find apartment document by ID across different collection structures
 */
async function findApartmentDocument(apartmentId) {
  try {
    // Newport uses structure: users/{blockId}/apartments/{apartmentNumber}
    // Parse apartment ID to get block and apartment number
    const parts = apartmentId.split('-') || apartmentId.split('_');
    
    if (parts.length >= 2) {
      const blockId = parts[0];
      const apartmentNumber = parts.slice(1).join('-');
      
      const apartmentRef = db.collection('users')
                            .doc(blockId)
                            .collection('apartments')
                            .doc(apartmentNumber);
      
      const doc = await apartmentRef.get();
      if (doc.exists) {
        return apartmentRef;
      }
    }

    // Fallback: search in apartments collection if exists
    const apartmentRef = db.collection('apartments').doc(apartmentId);
    const doc = await apartmentRef.get();
    
    if (doc.exists) {
      return apartmentRef;
    }

    console.warn(`Apartment document not found: ${apartmentId}`);
    return null;

  } catch (error) {
    console.error('Error finding apartment document:', error);
    return null;
  }
}

/**
 * Get user role from userProfiles collection (NOT users!)
 */
async function getUserRole(userUid) {
  try {
    // Check in userProfiles collection first (NEW - clean architecture)
    const userProfileDoc = await db.collection('userProfiles').doc(userUid).get();
    
    if (userProfileDoc.exists) {
      const data = userProfileDoc.data();
      return data.role || 'owner';
    }

    // Fallback: check if user owns any apartments
    const apartmentQuery = await db.collectionGroup('apartments')
                                  .where('passport_number', '==', userUid)
                                  .limit(1)
                                  .get();

    if (!apartmentQuery.empty) {
      return 'owner';
    }

    return 'guest';

  } catch (error) {
    console.error('Error getting user role:', error);
    return 'guest';
  }
}

/**
 * Send push notification to inviter about successful invitation acceptance
 */
async function notifyInviterOfAcceptance(inviterUid, newMemberName, apartmentCount) {
  try {
    // Find inviter's FCM tokens
    const fcmTokens = await getInviterFCMTokens(inviterUid);
    
    if (fcmTokens.length === 0) {
      console.log(`No FCM tokens found for inviter: ${inviterUid}`);
      return;
    }

    const apartmentText = apartmentCount === 1 ? 'квартире' : `${apartmentCount} квартирам`;
    
    const message = {
      notification: {
        title: '🎉 Новый член семьи',
        body: `${newMemberName} подключился к вашим ${apartmentText} в Newport`
      },
      data: {
        type: 'family_invitation_accepted',
        newMemberName: newMemberName,
        apartmentCount: apartmentCount.toString(),
        timestamp: Date.now().toString()
      },
      tokens: fcmTokens
    };

    const response = await admin.messaging().sendMulticast(message);
    console.log(`Sent invitation acceptance notification: ${response.successCount} success, ${response.failureCount} failed`);

  } catch (error) {
    console.error('Error sending notification to inviter:', error);
  }
}

/**
 * Get FCM tokens for the inviter
 */
async function getInviterFCMTokens(inviterUid) {
  try {
    const tokens = [];

    // Check user profile
    const userDoc = await db.collection('users').doc(inviterUid).get();
    if (userDoc.exists) {
      const data = userDoc.data();
      if (data.fcmTokens && Array.isArray(data.fcmTokens)) {
        tokens.push(...data.fcmTokens);
      }
      if (data.pushToken) {
        tokens.push(data.pushToken);
      }
    }

    // Check apartments owned by user
    const apartmentQuery = await db.collectionGroup('apartments')
                                  .where('passport_number', '==', inviterUid)
                                  .get();

    apartmentQuery.forEach(doc => {
      const data = doc.data();
      if (data.fcmTokens && Array.isArray(data.fcmTokens)) {
        tokens.push(...data.fcmTokens);
      }
      if (data.pushToken) {
        tokens.push(data.pushToken);
      }
    });

    // Remove duplicates
    return [...new Set(tokens)].filter(token => token && token.length > 10);

  } catch (error) {
    console.error('Error getting inviter FCM tokens:', error);
    return [];
  }
}

/**
 * Revoke invitation (callable function)
 */
exports.revokeFamilyInvite = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }

    const { inviteId } = data;
    const userUid = context.auth.uid;

    if (!inviteId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing invite ID');
    }

    const inviteDoc = await db.collection('invitations').doc(inviteId).get();
    
    if (!inviteDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Invitation not found');
    }

    const invite = inviteDoc.data();

    // Check if current user is the inviter
    if (invite.inviterUid !== userUid) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized to revoke this invitation');
    }

    if (invite.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Invitation cannot be revoked');
    }

    // Mark invitation as revoked
    await inviteDoc.ref.update({
      status: 'revoked',
      revokedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Invitation revoked: ${inviteId} by ${userUid}`);

    return { success: true, message: 'Invitation revoked successfully' };

  } catch (error) {
    console.error('Error revoking family invite:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Cleanup expired invitations (scheduled function)
 */
exports.cleanupExpiredInvitations = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      const expiredQuery = await db.collection('invitations')
                                  .where('status', '==', 'pending')
                                  .where('expiresAt', '<', now)
                                  .limit(100)
                                  .get();

      if (expiredQuery.empty) {
        console.log('No expired invitations found');
        return;
      }

      const batch = db.batch();
      expiredQuery.docs.forEach(doc => {
        batch.update(doc.ref, { status: 'expired' });
      });

      await batch.commit();
      console.log(`Cleaned up ${expiredQuery.docs.length} expired invitations`);

    } catch (error) {
      console.error('Error cleaning up expired invitations:', error);
    }
  }); 