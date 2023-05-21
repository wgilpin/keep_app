/* eslint-disable max-len */
/* eslint-disable camelcase */
/* eslint-disable require-jsdoc */
const index = require("../index.js");

// index.doTextSearch(
//     "ukraine",
//     10,
//     "zdt3YB86kJaxsESbMmkblkqQ3093")
//     .then((res) => {
//       console.log(res);
//     });

async function noteSearch() {
  index.doNoteSearch(
      "FgtHXS1200uAsLUyTjHx",
      10,
      "zdt3YB86kJaxsESbMmkblkqQ3093")
      .then((res) => {
        console.log(res);
      });
}
noteSearch();

// const {getFirestore, Timestamp} = require("firebase-admin/firestore");

// async function setTimes() {
//   const db = getFirestore();
//   const notes = await db.collection("notes").get();
//   const now = Timestamp.fromDate(new Date());
//   for (const n of notes.docs) {
//     if (n.data().created != null) {
//       db.
//           collection("notes").
//           doc(n.id).
//           update({"updatedAt": n.data().created});
//     } else {
//       db.
//           collection("notes").
//           doc(n.id).
//           update({"updatedAt": now});
//     }
//   }
// }

// setTimes();


