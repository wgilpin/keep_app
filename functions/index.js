/* eslint-disable require-jsdoc */
/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onCall} = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const functions = require('firebase-functions');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {initializeApp} = require('firebase-admin/app');
const similarity = require('compute-cosine-similarity');
const {stripHtml} = require('string-strip-html');
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} = require('firebase-functions/v2/firestore');

const THRESHOLD = 0.15;
const MAX_CACHE_SIZE = 20;

let ApiKey = null;
let myNotes = null;

initializeApp();
// const auth = getAuth(app);

// Create a new User object in Firestore when a user signs up
exports.setupNewUser = functions.auth.user().onCreate((user) => {
  const res = getFirestore()
      .collection('users')
      .doc(user.uid)
      .set(
          {
            display_name: user.displayName || user.email || 'anon',
            lastUpdated: Timestamp.now(),
          },
          {merge: true},
      );
  logger.debug('New user created', {uid: user.uid});
  return res;
});

/**
 * get the openai key from google cloud secret manager
 * @param {string} keyName the name of the key to fetch
 * @return {Promise<string>} the openai key
 */
async function getSecretKey(keyName) {
  try {
    if (ApiKey) {
      return ApiKey;
    }
    const {
      SecretManagerServiceClient,
    } = require('@google-cloud/secret-manager');
    const client = new SecretManagerServiceClient();
    const name = `projects/516790082055/secrets/${keyName}/versions/latest`;
    const res = await client.accessSecretVersion({name});
    ApiKey = res[0].payload.data.toString();
    return ApiKey;
  } catch (error) {
    logger.error('key service error ', keyName, {error});
  }
}

/**
 * get the embedding from the cache if present
 * @param {string} text the text to find
 * @return {Promise<Array<number>>} the embedding
 **/
async function getCachedTextSearch(text) {
  const findText = text.trim().toLowerCase();
  const res = await getFirestore()
      .collection('embeddings_cache')
      .doc(findText)
      .get();
  if (res.exists) {
    // update the timestamp for the FIFO cache
    getFirestore()
        .collection('embeddings_cache')
        .doc(findText)
        .update({timestamp: Timestamp.fromDate(new Date())}, {merge: true});
    return res.data().embedding;
  } else {
    return null;
  }
}

/**
 * cache the embedding for a text
 * @param {string} text the text to cache
 * @param {Array<number>} embedding the embedding to cache
 * @param {string} uid the user id
 **/
async function cacheTextEmbedding(text, embedding) {
  const cache = getFirestore().collection('embeddings_cache');
  // Check if the cache is full.
  // TODO: what if the cache is MAX_CACHE_SIZE + 2
  try {
    const snap = await cache.count().get();
    if (snap.exists) {
      if (snap.data().count >= MAX_CACHE_SIZE) {
        // Delete the oldest entry.
        cache
            .orderBy('timestamp', 'desc')
            .limit(1)
            .get()
            .then((snapshot) => {
              snapshot.docs[0].ref.delete();
            });
      }
    }
  } finally {
    cache.doc(text.trim().toLowerCase()).set({
      embedding: embedding,
      timestamp: Timestamp.fromDate(new Date()),
    });
  }
}

/**
 * get the embedding from hugging face
 * @param {string} text the text to embed
 * @return {Promise<Array<number>>} the embedding
 **/
async function getHFembeddings(text) {
  const model = 'all-MiniLM-L6-v2';
  const apiUrl = `https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/${model}`;
  const data = {inputs: text, wait_for_model: true};
  const hfToken = await getSecretKey('HF_API_KEY');
  let retries = 3;
  while (retries > 0) {
    try {
      // call the api
      const response = await fetch(apiUrl, {
        headers: {
          'Authorization': `Bearer ${hfToken}`,
          'pragma': 'no-cache',
          'cache-control': 'no-cache',
        },
        method: 'POST',
        body: JSON.stringify(data),
      });
      const res = await response.json();
      return res;
    } catch (error) {
      logger.warn('hf error', {error});
      retries--;
      // wait 3 seconds
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
  }
}

/**
 * get the embedding from openai
 * @param {string} text the text to embed
 * @param {boolean} useCache whether to use the cache
 * @return {Promise<Array<number>>} the embedding
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */
async function getTextEmbedding(text, useCache) {
  // check if the text has already been cached
  const embeddings = useCache ? await getCachedTextSearch(text) : null;
  if (embeddings == null) {
    try {
      const vector = await getHFembeddings(text);
      if (useCache) {
        try {
          // cache the embedding
          cacheTextEmbedding(text, vector);
          return vector;
        } catch (error) {
          logger.error('error getting embedding', error);
          return [];
        }
      } else {
        return vector;
      }
    } catch (error) {
      logger.error('API  error', {error});
      return [];
    }
  }
  return embeddings;
}

/**
 * get all notes for current user
 * @param {string} uid the user id
 * @return {Promise<Array<QueryDocumentSnapshot>>} the notes
 */
async function getMyNotes(uid) {
  if (myNotes) {
    return myNotes;
  }
  const userRef = getFirestore().collection('users').doc(uid);
  const res = await getFirestore()
      .collection('notes')
      .where('user', '==', userRef)
      .get();
  myNotes = res;
  return res;
}

/**
 * get notes similar to a text query
 * @param {string} text the text to search for
 * @param {myNotes} notes the notes to search
 * @param {string} uid the user id
 * @param {number} count the max number of notes to return
 * @return {Array<String>} ids of most similar notes sorted by similarity
 */
async function getSimilarToText(text, notes, uid, count = 10) {
  const textVector = await getTextEmbedding(text, true);
  const similarNoteIds = await vecSimilarRanked(
      [textVector],
      notes,
      null,
      count,
  );
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
  text = text.replace(/<\/p>/g, '</p>.');

  // strip the html
  text = stripHtml(text, {
    ignoreTagsWithTheirContents: ['code'],
    stripTogetherWithTheirContents: ['button'],
    skipHtmlDecoding: true,
  }).result;

  // replace any multiple periods with single periods
  text = text.replace(/\.{2,}/g, '. ');
  return text;
}

/**
 * get the 3 embeddings for a note title, snippet, comment
 * @param {string} noteSnapshot the note
 * @param {string} uid the user id
 * @return {Map<String, Array<number>>} the embeddings
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */
exports.getNoteEmbeddings = async (noteSnapshot, uid) => {
  const embSnap = await getFirestore()
      .collection('embeddings')
      .doc(noteSnapshot.id)
      .get();
  let titleVector;
  let commentVector;
  let snippetVector;
  if (embSnap.exists) {
    titleVector = embSnap.data().titleVector;
    snippetVector = embSnap.data().snippetVector;
    commentVector = embSnap.data().commentVector;
  } else {
    const {title, snippet, comment} = noteSnapshot.data();
    const vecs = await this.updateNoteEmbeddings(
        title,
        comment,
        snippet,
        noteSnapshot.id,
        uid,
    );
    [titleVector, snippetVector, commentVector] = vecs;
  }
  const dict = {};
  dict[noteSnapshot.id] = [titleVector, snippetVector, commentVector];
  return dict;
};

/**
 * get the 3 embeddings for a note title, snippet, comment
 * @param {string} title the note title
 * @param {string} comment the note comment
 * @param {string} snippet the note snippet
 * @param {string} noteId the note id
 * @param {string} uid the user id
 * @return {Array<Array<number>>} the embeddings
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */

exports.updateNoteEmbeddings = async (title, comment, snippet, noteId, uid) => {
  if (!(title || snippet || comment)) {
    return [];
  }

  const updates = {};

  if (title) {
    updates['titleVector'] = await getTextEmbedding(title, false);
  }

  if (snippet) {
    const clean = cleanSnippet(snippet);
    updates['snippetVector'] = await getTextEmbedding(clean, false);
  }

  if (comment) {
    updates['commentVector'] = await getTextEmbedding(comment, false);
  }

  logger.debug('updateNoteEmbeddings', noteId);
  // write any updates to the db
  await getFirestore()
      .collection('embeddings')
      .doc(noteId)
      .set(updates, {merge: true});

  return [
    updates['titleVector'],
    updates['snippetVector'],
    updates['commentVector'],
  ];
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
  for (let idx = 0; idx <= noteVecs.length; idx++) {
    // check the jth element of note- and search-Vecs both have embeddings
    if (
      noteVecs[idx] &&
      noteVecs[idx].length &&
      searchVecs[idx] &&
      searchVecs[idx].length
    ) {
      const cosDistance = similarity(noteVecs[idx], searchVecs[idx]);
      maxSimilarity = Math.max(maxSimilarity, cosDistance);
    }
  }
  return maxSimilarity;
}

/**
 * cache the related notes to the original note
 * @param {Array<string>} rankedNotes the ranked notes
 * @param {Array<dict>} related the related notes
 * @param {string} originalId the id of the original note
 * @param {string} userId the id of the user
 * @return {void}
 **/
function cacheRelated(rankedNotes, related, originalId, userId) {
  const now = Timestamp.fromDate(new Date());

  logger.debug('cacheRelated', originalId);
  // update the related notes for the original note
  getFirestore().collection('notes').doc(originalId).set(
      {
        related,
        relatedUpdated: now,
      },
      {merge: true},
  );
}

/**
 * get the 10 most similar notes to a search vector
 * @param {Array<Array<number>>} searchVecs array of the vectors to search for
 *                 (eg title, snippet, comment), or maybe just one
 * @param {Array<QueryDocumentSnapshot>} notes the notes to search through
 * @param {string} originalId the id of the note we are searching for, or null
 * @param {string} userId the id of the note's owner
 * @param {number} count the number of notes to return
 * @param {number} threshold the minimum similarity score to return
 * @return {Array<{id, title}>} ids of most similar notes sorted by similarity
 */
async function vecSimilarRanked(
    searchVecs,
    notes,
    originalId,
    userId,
    count = 10,
    threshold = THRESHOLD,
) {
  const promises = [];
  for (const n of notes.docs) {
    if (n.id != originalId) {
      promises.push(exports.getNoteEmbeddings(n, userId));
    }
  }
  const vecMaps = await Promise.all(promises);
  // make a single dict of all the embeddings
  const vecs = {};
  for (const vecMap of vecMaps) {
    vecs[Object.keys(vecMap)[0]] = Object.values(vecMap)[0];
  }
  // vecs is now 3 embeddings for each note
  // we have all the results, now calculate the similarity
  const similarityScores = {}; // id: score
  // eslint-disable-next-line guard-for-in
  for (const id in vecs) {
    // for a note with embs 'noteVec', calculate the similarity
    const score = getNoteSimilarity(vecs[id], searchVecs);
    console.log(`Similarity score : ${score} for ${id} v. ${originalId}`);
    if (score > threshold) {
      similarityScores[id] = score;
    }
  }
  // Sort score scores in descending order
  // -> list of [id, score]
  const sortedScores = Object.entries(similarityScores).sort(
      (a, b) => b[1] - a[1],
  );

  // Retrieve the top 'count' notes
  // -> list of ids
  const rankedNotes = sortedScores.slice(0, count).map((score) => score[0]);

  const related = rankedNotes.map((id) => {
    return {
      id,
      title: notes.docs.find((n) => n.id == id).data().title,
    };
  });

  // cache the related notes to the original note
  if (originalId) {
    // get an array of {id, title, updated} for the related notes
    cacheRelated(rankedNotes, related, originalId, userId);
  }
  return related;
}

/**
 * search for text in the notes
 * @param {string} searchText the text to search for
 * @param {number} maxResults the maximum number of results to return
 * @param {string} uid the user id
 * @return {dict<string, string>} the most similar notes sorted by similarity
 */
exports.doTextSearch = async function(searchText, maxResults, uid) {
  const notes = await getMyNotes(uid);
  const results = {};

  if (notes.length == 0) {
    logger.debug('textSearch - no notes', uid);
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
      results[snap.id] = note.title;
    }
  }

  if (Object.keys(results).length < maxResults) {
    const searchResults = await getSimilarToText(
        searchText,
        notes,
        uid,
        maxResults - results.size,
    );
    for (const r of searchResults) {
      // only add if the key not already in the set
      results[r.id] = r.title;
    }
  }

  return results;
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
 * @param {number} threshold - The minimum similarity score to return.
 * @return {Array<object>} the most similar notes sorted by similarity
 */
exports.doNoteSearch = async function(
    noteId,
    maxResults,
    uid,
    threshold = THRESHOLD,
) {
  // get the note
  const note = await getFirestore().collection('notes').doc(noteId).get();
  const {title, comment, snippet} = note.data();

  // only search if there are text fields
  if (title || comment || snippet) {
    // does the original note have a valid related cache?
    if (note.data().related && note.data().related.length) {
      const user = await getFirestore().collection('users').doc(uid).get();
      if (user.data().lastUpdated < note.data().relatedUpdated) {
        logger.debug('noteSearch - using cache', {
          uid,
          lastUpdated: user.data().lastUpdated,
          relatedUpdated: note.data().relatedUpdated,
        });
        return note.data().related;
      }
    }

    logger.debug('noteSearch - getting related');
    // we didn't find a valid cache, so search for related notes
    const notes = await getMyNotes(uid);

    // if the user has no other notes, return empty
    if (notes.length <= 1) {
      return [];
    }

    // get embeddings for this note
    const vector = await exports.getNoteEmbeddings(note, uid);

    // get the most similar notes
    const searchResults = await vecSimilarRanked(
        vector[noteId],
        notes,
        noteId,
        note.data().user.id,
        maxResults,
        threshold,
    );
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
 * @return {Array<{id, title}>} the most similar notes sorted by similarity
 */
exports.noteSearch = onCall(async (req) => {
  const {noteId, maxResults, threshold} = req.data;
  const uid = req.auth.uid;

  return exports.doNoteSearch(noteId, maxResults, uid, threshold);
});

// eslint-disable-next-line valid-jsdoc
/**
 * Firestore on-create trigger
 * Set the embeddings for a new note
 */
(exports.createNote = onDocumentCreated('notes/{noteId}')),
(event) => {
  // Get an object representing the document
  try {
    const newValue = event.data;
    getFirestore()
        .collection('notes')
        .doc(event.params.noteId)
        .set(
            {
              updatedAt: Timestamp.fromDate(new Date()),
            },
            {merge: true},
        )
        .catch((e) => {
          logger.error('note onCreated - error updating note', e);
          return false;
        });
    // record the update time to the user record
    const now = Timestamp.fromDate(new Date());
    getFirestore().collection('users').doc(event.data.user.id).update({
      lastUpdated: now,
    });

    exports
        .updateNoteEmbeddings(
            newValue.title,
            newValue.comment,
            newValue.snippet,
            event.params.noteId,
        )
        .then((_) => 'OK');
  } catch (error) {
    logger.error('note onCreated - error', error);
    return [];
  }
};

/**
 * Firestore on-delete trigger
 * Remove the embeddings for a deleted note
 */
exports.deleteNote = onDocumentDeleted('notes/{noteId}', (event) => {
  // record the update time to the user record
  const now = Timestamp.fromDate(new Date());
  getFirestore().collection('users').doc(event.data.user.id).update({
    lastUpdated: now,
  });

  // delete the note embeddings
  return getFirestore()
      .collection('embeddings')
      .doc(event.params.noteId)
      .delete();
});

/**
 * Firestore on-update trigger
 * Update the embeddings for a note
 */
exports.updateNote = onDocumentUpdated('notes/{noteId}', (event) => {
  try {
    // Get an object representing the document
    const newValue = event.data.after.data();

    // and the previous value before this update
    const previousValue = event.data.before.data();

    // we will pass either the changed title, comment or snippet or nulls
    const titleChange =
      newValue.title != previousValue.title ? newValue.title : null;
    const commentChange =
      newValue.comment != previousValue.comment ? newValue.comment : null;
    const snippetChange =
      newValue.snippet != previousValue.snippet ? newValue.snippet : null;

    // don't update if ~now already to avoid recursion
    const now = Timestamp.fromDate(new Date());
    // 500ms since last update? ignore
    if (titleChange || commentChange || snippetChange) {
      if (now - event.data.before.data().updatedAt > 500) {
        event.data.after.ref
            .set(
                {
                  updatedAt: Timestamp.fromDate(new Date()),
                },
                {merge: true},
            )
            .catch((e) => {
              logger.error('note onUpdate - error updating note', e);
              return false;
            });

        logger.debug('note onUpdate - updating user lastUpdated', {
          titleChange,
          commentChange,
          snippetChange,
        });
        // record the update time to the user record
        getFirestore().collection('users').doc(newValue.user.id).update({
          lastUpdated: now,
        });
      }
      logger.debug('note onUpdate - updating embeddings', event.params.noteId);
      exports
          .updateNoteEmbeddings(
              titleChange,
              commentChange,
              snippetChange,
              event.params.noteId,
          )
          .then((_) => 'OK');
    } else {
      return [];
    }
  } catch (error) {
    logger.error('note onUpdate - error', error);
    return [];
  }
});
