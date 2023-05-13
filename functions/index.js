/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require("firebase-functions");
const {getFirestore} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");

initializeApp();

// Create a new User object in Firestore when a user signs up
exports.setupNewUser = functions.auth.user().onCreate((user) => {
  logger.info(`New user creating: ${user.uid}`);
  getFirestore().
      collection("users").
      doc(user.uid).
      set(
          {"display_name": user.displayName||user.email||"anon"},
          {merge: true} );
  logger.info("New user created", {uid: user.uid});
});
