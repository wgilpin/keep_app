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
const {getFirestore} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");
const {Configuration, OpenAIApi} = require("openai");
const {dot, norm} = require("mathjs");
// const {getAuth} = require("firebase-admin/auth");

initializeApp();
// const auth = getAuth(app);


// Create a new User object in Firestore when a user signs up
exports.setupNewUser = functions.auth.user().onCreate((user) => {
  logger.debug("User to create", {user});
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
  logger.debug("getOpenaiKey");
  try {
    const {SecretManagerServiceClient} =
        require("@google-cloud/secret-manager");
    const client = new SecretManagerServiceClient();
    const name = "projects/516790082055/secrets/OPENAI_API_KEY/versions/1";
    const res = await client.accessSecretVersion({name});
    logger.debug("key service", {res});
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
  logger.debug("openai config", {embConfig});
  const emb = await openai.createEmbedding(embConfig);
  logger.debug(`getTextEmbedding for ${text}`, {emb});
  try {
    logger.debug("getTextEmbedding got embeddings");
    return emb.data.data[0]["embedding"];
  } catch (error) {
    logger.error("getTextEmbedding result error", error);
    return [];
  }
}

/**
 * get all notes for current user
 * @param {string} uid the user id
 * @return {Promise<Array<QueryDocumentSnapshot>>} the notes
 */
async function getMyNotes(uid) {
  logger.debug("getMyNotes", `/users/${uid}`);
  const userRef = getFirestore().collection("users").doc(uid);
  logger.debug("getMyNotes", userRef);
  const res = await getFirestore()
      .collection("notes")
      .where("user", "==", userRef)
      .get();
  return res;
}

/**
 * get notes similar to a text query
 * @param {string} text the text to search for
 * @param {string} uid the user id
 * @param {number} count the max number of notes to return
 * @return {Array<object>} the most similar notes sorted by similarity
 */
async function getSimilarToText(text, uid, count = 10) {
  const myNotes = await getMyNotes(uid);
  const textVector = await getTextEmbedding(text);
  const similarNoteIds = await vecSimilarRanked([textVector], myNotes, count);
  logger.debug("getSimilarToText res", {similarNoteIds});
  return similarNoteIds;
}

/**
 * are two urls on same domain
 * @param {string} url1 the first url
 * @param {string} url2 the second url
 * @return {boolean} true if the urls are on the same domain
 */

/**
 * get the 3 embeddings for a note title, snippet, comment
 * @param {QuerySnapshot} noteSnap the note to get embeddings for
 * @param {string} id the note id
 * @return {Array<Array<number>>} the embeddings
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */
async function getNoteEmbeddings(noteSnap) {
  const {title, snippet, comment} = noteSnap.data();
  let {
    title_vector: titleV,
    snippet_vector: snippetV,
    comment_vector: commentV} = noteSnap.data();
  if (!(title || snippet || comment)) {
    logger.debug("no text in noteSnap", noteSnap.id);
    return [];
  }

  let dirty = false;
  logger.debug(`getNoteEmbeddings :${noteSnap.id}`, {noteSnap});
  if (title && (!titleV || titleV.length==0)) {
    titleV = await getTextEmbedding(title);
    dirty = true;
    logger.debug("got title vector for ", noteSnap.id, titleV);
  } else {
    titleV = titleV||[];
  }

  if (snippet && (!snippetV||snippetV.length==0)) {
    snippetV = await getTextEmbedding(snippet);
    dirty = true;
    logger.debug("got snippet vector for ", noteSnap.id, snippetV);
  } else {
    snippetV = snippetV||[];
  }

  if (comment && (!commentV || commentV.length==0)) {
    commentV = await getTextEmbedding(comment);
    dirty = true;
    logger.debug("got comment vector for ", noteSnap.id, commentV);
  } else {
    logger.debug("Didn't get comment vector for ",
        noteSnap.id,
        !commentV);
    commentV = commentV||[];
  }

  if (dirty) {
    logger.debug("updating note", noteSnap.id);
    getFirestore().collection("notes").doc(noteSnap.id).set({
      title, snippet, comment,
      title_vector: titleV,
      snippet_vector: snippetV,
      comment_vector: commentV,
    });
  }
  const res = [titleV, snippetV, commentV];
  logger.debug("got note embeddings", noteSnap.id, res);
  return res;
}

/**
 * get the cosine distance between two vectors
 * @param {Array<number>} v1 the first vector
 * @param {Array<number>} v2 the second vector
 * @return {number} the cosine distance between v1 and v2
 */
function cosDistance(v1, v2) {
  try {
    return dot(v1, v2) / (norm(v1) * norm(v2));
  } catch (_) {
    return 0.0;
  }
}

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
    if (noteVecs[idx] && searchVecs[idx]) {
      const similarity = (cosDistance(noteVecs[idx], searchVecs[idx]));
      maxSimilarity = Math.max(maxSimilarity, similarity);
    }
  }
  return maxSimilarity;
}
/**
  * get the 10 most similar notes to a search vector
  * @param {Array<Array<number>>} searchVecs array of the vectors to search for
*                                (eg title, snippet, comment), or maybe just one
  * @param {Array<QueryDocumentSnapshot>} notes the notes to search through
  * @param {number} count the number of notes to return
  * @param {number} threshold the minimum similarity score to return
  * @return {Array<String>} the ids of most similar notes sorted by similarity
  */
async function vecSimilarRanked(
    searchVecs, notes, count = 10, threshold = 0.7) {
  logger.debug("vectorSimilaritiesRanked #", notes.length);
  const promises = [];
  for (const n of notes.docs) {
    promises.push(await getNoteEmbeddings(n));
  }
  const vecs = await Promise.all(promises);
  // vecs is now 3 embeddings for each note
  logger.debug("vectorSimilaritiesRanked all vecs", vecs.length);
  // we have all the results, now calculate the similarity
  const similarityScores = {};
  for (let i=0; i < vecs.length; i++) {
    // for a note with embs 'noteVec', calculate the similarity
    const similarity = getNoteSimilarity(vecs[i], searchVecs);
    if (similarity > threshold) {
      logger.debug(`note ${notes.docs[i].id} over threshold: ${similarity}`);
      similarityScores[notes.docs[i].id] = similarity;
    } else {
      logger.debug(`note ${notes.docs[i].id} under threshold: ${similarity}`);
    }
  }
  logger.debug("vectorSimilaritiesRanked similarityScores", {similarityScores});
  // Sort similarity scores in descending order
  const sortedScores = Object.entries(
      similarityScores).sort((a, b) => b[1] - a[1]);

  // Retrieve the top 'count' notes
  const rankedNotes = sortedScores
      .slice(0, count)
      .map((score) => score[0]);

  return Array(rankedNotes);
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
  const results = [];
  const resultSet = {};

  if (notes.length == 0) {
    logger.debug("textSearch - no notes");
    return [];
  }

  for (const snap of notes.docs) {
    const note = snap.data();
    if (
      note.title.toLowerCase().includes(searchText.toLowerCase()) ||
      note.comment.toLowerCase().includes(searchText.toLowerCase()) ||
      note.snippet.toLowerCase().includes(searchText.toLowerCase())
    ) {
      results.push(note);
      resultSet[snap.id] = true;
    }
  }

  if (results.length < maxResults) {
    const searchResults = await getSimilarToText(
        searchText,
        uid,
        maxResults - results.length);
    logger.debug("textSearch results", searchResults);
    for (const r of searchResults) {
      if (! (r in resultSet)) {
        results.push(r);
      }
    }
  }
  return results;
};

/**
 * FUNCTION: search for text in the notes
 * @param {Object} req - The parameters object.
 * @param {string} req.searchText - The search text.
 * @param {number} req.maxResults - The maximum number of results.
 * @return {Array<QuerySnapshot>} the most similar notes sorted by similarity
 */
exports.textSearch = onCall(async (req) => {
  const {searchText, maxResults} = req.data;
  const uid = req.auth.uid;
  logger.debug("textSearch user", uid);
  exports.doTextSearch(searchText, maxResults, uid);
});

/**
 * search for text in the notes
 * @param {string} noteId - ID of the note to compare
 * @param {number} maxResults - The maximum number of results.
 * @param {string} uid - The user id.
 * @return {Array<object>} the most similar notes sorted by similarity
 */
exports.doNoteSearch = async function(noteId, maxResults, uid) {
  // do vector search
  const note = await getFirestore().collection("notes").doc(noteId).get();
  const {title, comment, snippet} = note.data();
  logger.debug("noteSearch 2 note",
      {note, fields: (title || comment || snippet)});
  if (title || comment || snippet) {
    logger.debug("noteSearch 3 content found");
    const notes = await getMyNotes(uid);

    // if the user has no notes, return empty
    if (notes.length == 0) {
      logger.debug("noteSearch 4 - no notes");
      return [];
    }

    logger.debug("noteSearch 5", noteId);

    const vector = await getNoteEmbeddings(note);
    const searchResults = await vecSimilarRanked(vector, notes, maxResults);
    logger.debug("noteSearch 6 results", searchResults);
    return searchResults;
  } else {
    logger.debug("noteSearch 7 - no text");
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
  logger.debug("noteSearch IN ", {noteId, maxResults});
  const uid = req.auth.uid;

  exports.doNoteSearch(noteId, maxResults, uid);
});
