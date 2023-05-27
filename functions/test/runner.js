/* eslint-disable max-len */
/* eslint-disable camelcase */
/* eslint-disable require-jsdoc */
const index = require("../index.js");

// index
//     .doTextSearch("ukraine", 10, "zdt3YB86kJaxsESbMmkblkqQ3093")
//     .then((res) => {
//       console.log(res);
//     });

async function noteSearch() {
  index
      .doNoteSearch("EskGBMtnoSUXFOrqI4dV", 10, "zdt3YB86kJaxsESbMmkblkqQ3093")
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
