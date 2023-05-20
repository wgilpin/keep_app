/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require("firebase-functions");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");
const {Configuration, OpenAIApi} = require("openai");
const similarity = require( "compute-cosine-similarity" );
const {stripHtml} = require("string-strip-html");

initializeApp();
// const auth = getAuth(app);


// Create a new User object in Firestore when a user signs up
exports.setupNewUser = functions.auth.user().onCreate((user) => {
  const res = getFirestore().
      collection("users").
      doc(user.uid).
      set(
          {"display_name": user.displayName||user.email||"anon"},
          {merge: true} );
  logger.debug("New user created", {uid: user.uid});
  return res;
});

/**
 * get the openai key from google cloud secret manager
 *
 * @return {Promise<string>} the openai key
 */
async function getOpenaiKey() {
  try {
    const {SecretManagerServiceClient} =
        require("@google-cloud/secret-manager");
    const client = new SecretManagerServiceClient();
    const name = "projects/516790082055/secrets/OPENAI_API_KEY/versions/1";
    const res = await client.accessSecretVersion({name});
    return res[0].payload.data.toString();
  } catch (error) {
    logger.error("key service error ", error);
  }
}
/**
 * get the embedding from openai
 * @param {string} text the text to embed
 * @param {string} model the model to use
 * @return {Promise<Array<number>>} the embedding
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */
async function getTextEmbedding(text, model="text-embedding-ada-002") {
  const configuration = new Configuration({
    apiKey: process.env.OPENAI_API_KEY || await getOpenaiKey(),
    organization: "org-WdPppWM3ixsbsP3FgYID3E9K",
  });

  text = text.replace("\n", " ");
  const openai = new OpenAIApi(configuration);
  const embConfig = {
    input: text,
    model,
  };
  const emb = await openai.createEmbedding(embConfig);
  try {
    return emb.data.data[0]["embedding"];
  } catch (error) {
    return [];
  }
}

/**
 * get all notes for current user
 * @param {string} uid the user id
 * @return {Promise<Array<QueryDocumentSnapshot>>} the notes
 */
async function getMyNotes(uid) {
  const userRef = getFirestore().collection("users").doc(uid);
  const res = await getFirestore()
      .collection("notes")
      .where("user", "==", userRef)
      .get();
  return res;
}

/**
 * get notes similar to a text query
 * @param {string} text the text to search for
 * @param {myNotes} notes the notes to search
 * @param {number} count the max number of notes to return
 * @return {Array<String>} ids of most similar notes sorted by similarity
 */
async function getSimilarToText(text, notes, count = 10) {
  const textVector = await getTextEmbedding(text);
  const similarNoteIds = await vecSimilarRanked(
      [textVector],
      notes,
      null,
      count);
  return similarNoteIds;
}
/**
 * clean the HTM out of the snippet
 * @param {string} text the text to clean
 * @return {string} the cleaned text
 * @see https://www.npmjs.com/package/string-strip-html
 */
function cleanSnippet(text) {
  // replace </p> with </p>. in the text
  // so sentences are delimed by periods
  text = text.replace(/<\/p>/g, "</p>.");

  // strip the html
  text = stripHtml(text, {
    ignoreTagsWithTheirContents: ["code"],
    stripTogetherWithTheirContents: ["button"],
    skipHtmlDecoding: true,
  }).result;

  // replace any multiple periods with single periods
  text = text.replace(/\.{2,}/g, ". ");
  return text;
}

/**
 * get the 3 embeddings for a note title, snippet, comment
 * @param {string} noteId the note id
 * @return {Array<Array<number>>} the embeddings
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */
async function getNoteEmbeddings(noteId) {
  const embSnap = await getFirestore()
      .collection("embeddings")
      .doc(noteId)
      .get();
  const titleVector = embSnap.data().titleVector;
  const snippetVector = embSnap.data().snippetVector;
  const commentVector = embSnap.data().commentVector;
  return [titleVector, snippetVector, commentVector];
}

/**
 * get the 3 embeddings for a note title, snippet, comment
 * @param {string} title the note title
 * @param {string} comment the note comment
 * @param {string} snippet the note snippet
 * @param {QuerySnapshot} noteSnap the note to get embeddings for
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */

exports.updateNoteEmbeddings= async (title, comment, snippet, noteId) => {
  if (!(title || snippet || comment)) {
    return [];
  }

  const updates = {};

  if (title) {
    updates["titleVector"] = await getTextEmbedding(title);
  }

  if (snippet) {
    const clean = cleanSnippet(snippet);
    updates["snippetVector"] = await getTextEmbedding(clean);
  }

  if (comment) {
    updates["commentVector"] = await getTextEmbedding(comment);
  }

  // write any updates to the db
  return getFirestore()
      .collection("embeddings")
      .doc(noteId)
      .set(updates, {merge: true});
};


/**
 * for a note with embs 'noteVecs', calculate the similarity with searchVecs
 * @param {Array<number>} noteVecs the embeddings of the note
 * @param {Array<number>} searchVecs the embeddings of the search query
 * @return {number} the max similarity between them
 */
function getNoteSimilarity(noteVecs, searchVecs) {
  let maxSimilarity = 0.0;
  // if seasrchVecs has only one vector, repeat it for each noteVec
  // this happens wehn the searchVec is from a text search
  if (searchVecs.length == 1) {
    searchVecs = Array(noteVecs.length).fill(searchVecs[0]);
  }
  // if there are embeddings and the search vector has embeddings
  for (let idx=0; idx <= noteVecs.length; idx++) {
    // check the jth element of note- and search-Vecs both have embeddings
    if (noteVecs[idx] &&
        noteVecs[idx].length &&
        searchVecs[idx] &&
        searchVecs[idx].length) {
      const cosDistance = similarity(noteVecs[idx], searchVecs[idx]);
      maxSimilarity = Math.max(maxSimilarity, cosDistance);
    }
  }
  return maxSimilarity;
}
/**
  * get the 10 most similar notes to a search vector
  * @param {Array<Array<number>>} searchVecs array of the vectors to search for
*                                (eg title, snippet, comment), or maybe just one
  * @param {Array<QueryDocumentSnapshot>} notes the notes to search through
  * @param {string} originalId the id of the note we are searching for, or null
  * @param {number} count the number of notes to return
  * @param {number} threshold the minimum similarity score to return
  * @return {Array<String>} the ids of most similar notes sorted by similarity
  */
async function vecSimilarRanked(
    searchVecs, notes, originalId, count = 10, threshold = 0.7) {
  const promises = [];
  for (const n of notes.docs) {
    if (n.id != originalId) {
      promises.push(getNoteEmbeddings(n.id));
    }
  }
  const vecs = await Promise.all(promises);

  // vecs is now 3 embeddings for each note
  // we have all the results, now calculate the similarity
  const similarityScores = {}; // id: score
  for (let i=0; i < vecs.length; i++) {
    // for a note with embs 'noteVec', calculate the similarity
    const score = getNoteSimilarity(vecs[i], searchVecs);
    if (score > threshold) {
      similarityScores[notes.docs[i].id] = score;
    }
  }
  // Sort score scores in descending order
  // -> list of [id, score]
  const sortedScores = Object.entries(
      similarityScores).sort((a, b) => b[1] - a[1]);

  // Retrieve the top 'count' notes
  // -> list of ids
  const rankedNotes = sortedScores
      .slice(0, count)
      .map((score) => score[0]);

  return rankedNotes;
}

/**
 * search for text in the notes
 * @param {string} searchText the text to search for
 * @param {number} maxResults the maximum number of results to return
 * @param {string} uid the user id
 * @return {Array<QuerySnapshot>} the most similar notes sorted by similarity
 */
exports.doTextSearch = async function(searchText, maxResults, uid) {
  const notes = await getMyNotes(uid);
  const results = new Set();

  if (notes.length == 0) {
    logger.debug("textSearch - no notes", uid);
    return [];
  }

  const searchTextLower = searchText.toLowerCase();
  for (const snap of notes.docs) {
    const note = snap.data();
    if (
      note.title.toLowerCase().includes(searchTextLower) ||
      note.comment.toLowerCase().includes(searchTextLower) ||
      note.snippet.toLowerCase().includes(searchTextLower)
    ) {
      results.add(snap.id);
    }
  }

  if (results.size < maxResults) {
    const searchResults = await getSimilarToText(
        searchText,
        notes,
        maxResults - results.size);
    for (const r of searchResults) {
      results.add(r);
    }
  }

  const retValue = Array.from(results);
  return retValue;
};

/** FUNCTION: search for text in the notes
 * @param {Object} req - The parameters object.
 * @param {string} req.searchText - The search text.
 * @param {number} req.maxResults - The maximum number of results.
 * @return {Array<QuerySnapshot>} the most similar notes sorted by similarity
 */
exports.textSearch = onCall(async (req) => {
  const {searchText, maxResults} = req.data;
  const uid = req.auth.uid;
  return exports.doTextSearch(searchText, maxResults, uid);
});

/**
 * search for text in the notes
 * @param {string} noteId - ID of the note to compare
 * @param {number} maxResults - The maximum number of results.
 * @param {string} uid - The user id.
 * @return {Array<object>} the most similar notes sorted by similarity
 */
exports.doNoteSearch = async function(noteId, maxResults, uid) {
  // get the note
  const note = await getFirestore().collection("notes").doc(noteId).get();
  const {title, comment, snippet} = note.data();

  // only search if there are text fields
  if (title || comment || snippet) {
    const notes = await getMyNotes(uid);

    // if the user has no other notes, return empty
    if (notes.length <= 1) {
      return [];
    }

    // get embeddings for this note
    const vector = await getNoteEmbeddings(note.id);

    // get the most similar notes
    const searchResults = await vecSimilarRanked(
        vector,
        notes,
        noteId,
        maxResults);
    return searchResults;
  } else {
    // if the note has no text fields, return empty
    return [];
  }
};


/**
 * search for text in the notes
 * @param {Object} req - The parameters object.
 * @param {string} req.noteId - ID of the note to compare
 * @param {number} req.maxResults - The maximum number of results.
 * @return {Array<object>} the most similar notes sorted by similarity
 */
exports.noteSearch = onCall(async (req) => {
  const {noteId, maxResults} = req.data;
  const uid = req.auth.uid;

  return exports.doNoteSearch(noteId, maxResults, uid);
});

/**
 * Firestore on-create trigger
 * Set the embeddings for a new note
 */
exports.createNote = functions.firestore
    .document("notes/{noteId}")
    .onCreate((snap, context) => {
      // Get an object representing the documenttry {
      try {
        const newValue = snap.data();
        logger.debug("createNote 1", snap);
        getFirestore()
            .collection("notes")
            .doc(context.params.noteId)
            .set(
                {
                  updatedAt: Timestamp.fromDate(new Date()),
                }, {merge: true})
            .catch((e) => {
              logger.error("note onCreated - error updating note", e);
              return false;
            });
        logger.debug("createNote 2", context.params.noteId);
        return exports.updateNoteEmbeddings(
            newValue.title,
            newValue.comment,
            newValue.snippet,
            context.params.noteId);
      } catch (error) {
        logger.error("note onCreated - error", error);
        return [];
      }
    });

/**
 * Firestore on-delete trigger
 * Remove the embeddings for a deleted note
 */
exports.deleteNote = functions.firestore
    .document("notes/{noteId}")
    .onDelete((_, context) => {
      logger.debug("deleteNote", context.params.noteId);
      return getFirestore()
          .collection("embeddings")
          .doc(context.params.noteId)
          .delete();
    });

/**
 * Firestore on-update trigger
 * Update the embeddings for a note
 */
exports.updateNote = functions.firestore
    .document("notes/{noteId}")
    .onUpdate((change, context) => {
      // Get an object representing the document
      const newValue = change.after.data();

      // and the previous value before this update
      const previousValue = change.before.data();

      // we will pass either the changed title, comment or snippet or nulls
      const titleChange =
        newValue.title != previousValue.title? newValue.title : null;
      const commentChange =
        newValue.comment != previousValue.comment? newValue.comment : null;
      const snippetChange =
        newValue.snippet != previousValue.snippet? newValue.snippet : null;

      // don't update if ~now already to avoid recursion
      const now = Timestamp.fromDate(new Date());
      // 500ms since last update? ignore
      if (now - change.before.data().updatedAt > 500) {
        change.after.ref.set(
            {
              updatedAt: Timestamp.fromDate(new Date()),
            }, {merge: true})
            .catch((e) => {
              logger.error("note onUpdate - error updating note", e);
              return false;
            });
      }

      return exports.updateNoteEmbeddings(
          titleChange,
          commentChange,
          snippetChange,
          context.params.noteId);
    });
