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
 * @return {Promise<Array<object>>} the notes
 */
async function getMyNotes(uid) {
  return await getFirestore()
      .collection("notes")
      .where("user_id", "==", `/users/${uid}`)
      .get()
      .then((snapshot) => snapshot.docs.map((doc) => doc.data()));
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
 * @param {object} note the note to get embeddings for
 * @return {Array<Array<number>>} the embeddings
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */
async function getNoteEmbeddings(note) {
  if (!(note.title || note.snippet || note.comment)) {
    logger.debug("no text in note", note);
    return [];
  }

  let dirty = false;
  logger.debug("getNoteEmbeddings", {note});
  if (note.title && (!note.title_vector || note.title_vector.length==0)) {
    note.title_vector = await getTextEmbedding(note.title);
    dirty = true;
    logger.debug("got title vector for ", note.id, note.title_vector);
  } else {
    note.title_vector = note.title_vector||[];
  }

  if (note.snippet && (!note.snippet_vector||note.snippet_vector.length==0)) {
    note.snippet_vector = await getTextEmbedding(note.snippet);
    dirty = true;
    logger.debug("got snippet vector for ", note.id, note.snippet_vector);
  } else {
    note.snippet_vector = note.snippet_vector||[];
  }

  if (note.comment && (!note.comment_vector || note.comment_vector.length==0)) {
    note.comment_vector = await getTextEmbedding(note.comment);
    dirty = true;
    logger.debug("got comment vector for ", note.id, note.comment_vector);
  } else {
    logger.debug("Didn't get comment vector for ",
        note.id,
        !note.comment_vector);
    note.comment_vector = note.comment_vector||[];
  }

  if (dirty) {
    logger.debug("updating note", note);
    getFirestore().collection("notes").doc(note.id).set(note);
  }
  const res = [note.title_vector, note.snippet_vector, note.comment_vector];
  logger.debug("got note embeddings", note.id, res);
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
  *                                         (eg title, snippet, comment)
  * @param {Array<object>} notes the notes to search through
  * @param {number} count the number of notes to return
  * @param {number} threshold the minimum similarity score to return
  * @return {Array<object>} the most similar notes sorted by similarity
  */
async function vecSimilarRanked(
    searchVecs, notes, count = 10, threshold = 0.7) {
  logger.debug("vectorSimilaritiesRanked #", notes.length);
  const promises = [];
  for (const n of notes) {
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
      logger.debug(`note ${notes[i].id} over threshold: ${similarity}`);
      similarityScores[notes[i].id] = similarity;
    } else {
      logger.debug(`note ${notes[i].id} under threshold: ${similarity}`);
    }
  }
  logger.debug("vectorSimilaritiesRanked similarityScores", {similarityScores});
  // Sort similarity scores in descending order
  const sortedScores = Object.entries(
      similarityScores).sort((a, b) => b[1] - a[1]);

  // Retrieve the top 'count' notes
  const rankedNotes = sortedScores
      .slice(0, count)
      .map(([id]) => notes.find((n) => n.id == id));

  return rankedNotes;
}

/**
  * get the 10 most similar notes to a given note
  * @param {Object} params - The parameters object.
  * @param {string} params.noteId - The ID of the note to compare to.
  * @param {number} params.count - The maximum number of results.
  * @param {Object} context - The context object.
  * @param {Object} context.auth - The authentication information.
  * @return {Array<object>} the most similar notes sorted by similarity
  */
exports.getSimilarToNote = async function({noteId, count}, {auth}) {
  const uid = auth.uid;
  const note = await getFirestore().collection("notes").doc(noteId).get();
  if (note.title) {
    const notes = await getMyNotes(uid);
    const vector = await getNoteEmbeddings(note);
    return await vecSimilarRanked(vector, notes, count);
  } else {
    return [];
  }
};

/**
 * search for text in the notes
 * @param {Object} req - The parameters object.
 * @param {string} req.searchText - The search text.
 * @param {number} req.maxResults - The maximum number of results.
 * @return {Array<object>} the most similar notes sorted by similarity
 */
exports.textSearch = onCall(async (req) => {
  const {searchText, maxResults} = req.data;
  const uid = req.auth.uid;
  logger.debug("textSearch user", uid);
  const notes = await getMyNotes(uid);
  const results = [];
  const resultSet = {};

  if (notes.length == 0) {
    logger.debug("textSearch - no notes");
    return [];
  }

  for (const n of notes) {
    if (
      n.title.toLowerCase().includes(searchText.toLowerCase()) ||
      n.comment.toLowerCase().includes(searchText.toLowerCase()) ||
      n.snippet.toLowerCase().includes(searchText.toLowerCase())
    ) {
      results.push(n);
      resultSet[n.id] = true;
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
});
