/* eslint-disable max-len */
/* eslint-disable camelcase */
/* eslint-disable require-jsdoc */
const index = require("../index.js");

index.doTextSearch("vector", 10, "zdt3YB86kJaxsESbMmkblkqQ3093").then((res) => {
  console.log(res);
});

async function noteSearch() {
  index
      .doNoteSearch("Gk68uFIcukBglSfaVDAk", 10, "zdt3YB86kJaxsESbMmkblkqQ3093")
      .then((res) => {
        console.log(res);
      });
}
noteSearch();

// const {getFirestore, Timestamp} = require("firebase-admin/firestore");

// async function deleteRelated() {
//   const db = getFirestore();
//   const notes = await db.collection("notes").get();
//   for (const n of notes.docs) {
//     db.collection("notes")
//         .doc(n.id)
//         .update({related: null, relatedUpdated: Timestamp.fromMillis(0)});
//   }
// }

// deleteRelated();

// // check simialririty for note
// // const { getFirestore } = require("firebase-admin/firestore");
// const {getNoteEmbeddings} = require("../index.js");
// const similarity = require("compute-cosine-similarity");

// async function checkRelated(noteId, withIds) {
//   const db = getFirestore();
//   const allNotes = {};
//   if (withIds) {
//     for (const nId of withIds) {
//       const cf = await db.collection("notes").doc(nId).get();
//       allNotes[nId] = cf.data();
//     }
//   } else {
//     const allNotesSnap = await db.collection("notes").get();
//     for (const snap of allNotesSnap.docs) {
//       allNotes[snap.id] = snap.data();
//     }
//   }

//   const noteSnap = await db.collection("notes").doc(noteId).get();
//   const vectorDict = await getNoteEmbeddings(noteId);
//   const vector = vectorDict[noteId];
//   console.log("OP.title", noteSnap.data().title.substring(0, 75));
//   console.log("OP.Snippet", noteSnap.data().snippet.substring(0, 75));
//   console.log("OP.Comment", noteSnap.data().comment.substring(0, 75));
//   console.log("--------------------");
//   // eslint-disable-next-line guard-for-in
//   for (const nId in allNotes) {
//     console.log(nId);
//     const cf = allNotes[nId];
//     const emb_dict = await getNoteEmbeddings(nId);
//     const cf_emb = emb_dict[nId];
//     if (cf_emb[0] && vector[0]) {
//       console.log(
//           parseFloat(similarity(vector[0], cf_emb[0]).toFixed(3)),
//           "Title  :",
//           cf.title.substring(0, 75),
//       );
//     }
//     if (cf_emb[1] && vector[1]) {
//       console.log(
//           parseFloat(similarity(vector[1], cf_emb[1]).toFixed(3)),
//           "Snippet:",
//           cf.snippet.substring(0, 75),
//       );
//     }
//     if (cf_emb[2] && vector[2]) {
//       console.log(
//           parseFloat(similarity(vector[2], cf_emb[2]).toFixed(3)),
//           "Comment:",
//           cf.comment.substring(0, 75),
//       );
//     }
//   }
// }

// checkRelated("EskGBMtnoSUXFOrqI4dV");
