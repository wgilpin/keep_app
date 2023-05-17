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
const similarity = require( "compute-cosine-similarity" );
const {stripHtml} = require("string-strip-html");

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
  const emb = await openai.createEmbedding(embConfig);
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
  const similarNoteIds = await vecSimilarRanked(
      [textVector],
      myNotes,
      null,
      count);
  logger.debug("getSimilarToText res", {similarNoteIds});
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
  logger.debug(`getNoteEmbeddings :${noteSnap.id}`);
  if (title && (!titleV || titleV.length==0)) {
    titleV = await getTextEmbedding(title);
    dirty = true;
    logger.debug("got title vector for ", noteSnap.id, titleV.length);
  } else {
    titleV = titleV||[];
  }

  if (snippet && (!snippetV||snippetV.length==0)) {
    const clean = cleanSnippet(snippet);
    snippetV = await getTextEmbedding(clean);
    dirty = true;
    logger.debug("got snippet vector for ", noteSnap.id, snippetV.length);
  } else {
    snippetV = snippetV||[];
  }

  if (comment && (!commentV || commentV.length==0)) {
    commentV = await getTextEmbedding(comment);
    dirty = true;
    logger.debug("got comment vector for ", noteSnap.id, commentV.length);
  } else {
    logger.debug("Didn't get comment vector for ",
        noteSnap.id);
    commentV = commentV||[];
  }

  if (dirty) {
    logger.debug("updating note", noteSnap.id);
    getFirestore().collection("notes").doc(noteSnap.id).set({
      title, snippet, comment,
      title_vector: titleV,
      snippet_vector: snippetV,
      comment_vector: commentV,
    }, {merge: true});
  }
  const res = [titleV, snippetV, commentV];
  logger.debug("got note embeddings", noteSnap.id);
  return res;
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
    if (noteVecs[idx] &&
        noteVecs[idx].length &&
        searchVecs &&
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
  logger.debug("vectorSimilaritiesRanked #", notes.length);
  const promises = [];
  for (const n of notes.docs) {
    if (n.id != originalId) {
      promises.push(await getNoteEmbeddings(n));
    }
  }
  const vecs = await Promise.all(promises);
  // vecs is now 3 embeddings for each note
  logger.debug("vectorSimilaritiesRanked all vecs", vecs.length);
  // we have all the results, now calculate the similarity
  const similarityScores = {};
  for (let i=0; i < vecs.length; i++) {
    // for a note with embs 'noteVec', calculate the similarity
    const score = getNoteSimilarity(vecs[i], searchVecs);
    if (score > threshold) {
      logger.debug(`note ${notes.docs[i].id} over threshold: ${score}`);
      similarityScores[notes.docs[i].id] = score;
    } else {
      logger.debug(`note ${notes.docs[i].id} under threshold: ${score}`);
    }
  }
  logger.debug("vectorSimilaritiesRanked similarityScores", {similarityScores});
  // Sort score scores in descending order
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
  // do vector search
  const note = await getFirestore().collection("notes").doc(noteId).get();
  const {title, comment, snippet} = note.data();
  logger.debug("doNoteSearch 2 note",
      {id: note.id, fields: (title || comment || snippet)});
  if (title || comment || snippet) {
    logger.debug("doNoteSearch 3 content found");
    const notes = await getMyNotes(uid);

    // if the user has no notes, return empty
    if (notes.length == 0) {
      logger.debug("doNoteSearch 4 - no notes");
      return [];
    }

    logger.debug("doNoteSearch 5", noteId);

    const vector = await getNoteEmbeddings(note);
    logger.debug("doNoteSearch 6", noteId);
    const searchResults = await vecSimilarRanked(
        vector,
        notes,
        noteId,
        maxResults);
    logger.debug("doNoteSearch 7 results", searchResults);
    return searchResults;
  } else {
    logger.debug("doNoteSearch 8 - no text");
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

  return exports.doNoteSearch(noteId, maxResults, uid);
});
