/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as firebaseFunctions from 'firebase-functions'
import {QuerySnapshot, getFirestore, Timestamp} from 'firebase-admin/firestore'
import {onCall} from 'firebase-functions/v2/https'
import {logger} from 'firebase-functions'
import {initializeApp} from 'firebase-admin/app'
// eslint-disable-next-line @typescript-eslint/no-var-requires
const similarity = require('compute-cosine-similarity')
import {stripHtml} from 'string-strip-html'
import {onDocumentCreated, onDocumentUpdated, onDocumentDeleted} from 'firebase-functions/v2/firestore'
import {SecretManagerServiceClient} from '@google-cloud/secret-manager'

const THRESHOLD = 0.2
const MAX_CACHE_SIZE = 20

let ApiKey: string | null = null

initializeApp()

// [id, title]
export type NoteSummary = [string, string]

/**
 * Convert a list of noteSummary to a list of objects with id and title
 * @param {NoteSummary[]} summaries
 * @return {object[]} list of objects
 */
function noteSummariesToIds(summaries: NoteSummary[]): object[] {
  const res: object[] = []
  for (const s of summaries) {
    res.push({id: s[0], title: s[1]})
  }
  return res
}

// Create a new User object in Firestore when a user signs up
export const setupNewUser = firebaseFunctions.auth.user().onCreate((user) => {
  const res = getFirestore()
    .collection('users')
    .doc(user.uid)
    .set(
      {
        display_name: user.displayName || user.email || 'anon',
        lastUpdated: Timestamp.now(),
      },
      {merge: true}
    )
  logger.debug('New user created', {uid: user.uid})
  return res
})

/**
 * get the openai key from google cloud secret manager
 * @param {string} keyName the name of the key to fetch
 * @return {Promise<string>} the openai key
 */
async function getSecretKey(keyName: string): Promise<string | null> {
  let retries = 3
  while (retries > 0) {
    try {
      if (ApiKey) {
        return ApiKey
      }

      const client = new SecretManagerServiceClient()
      const name = `projects/516790082055/secrets/${keyName}/versions/latest`
      const res = await client.accessSecretVersion({name})
      ApiKey = res[0]?.payload?.data?.toString() ?? null
      return ApiKey
    } catch (error) {
      logger.error('key service error ', keyName, {error})
      retries--
      return null
    }
  }
  return null
}

/**
 * get the embedding from the cache if present
 * @param {string} text the text to find
 * @return {Promise<number[]>} the embedding
 **/
async function getCachedTextSearch(text: string): Promise<number[]> {
  const findText: string = text.trim().toLowerCase()
  const res = await getFirestore().collection('embeddings_cache').doc(findText).get()
  if (res.exists) {
    // update the timestamp for the FIFO cache
    // @ts-expect-error Firebase call
    getFirestore()
      .collection('embeddings_cache')
      .doc(findText)
      .update({timestamp: Timestamp.fromDate(new Date())}, {merge: true})
    return res?.data()?.embedding
  } else {
    return []
  }
}

/**
 * cache the embedding for a text
 * @param {string} text the text to cache
 * @param {number[]} embedding the embedding to cache
 * @param {string} uid the user id
 **/
async function cacheTextEmbedding(text: string, embedding: number[]) {
  const cache = getFirestore().collection('embeddings_cache')
  // Check if the cache is full.
  // TODO: what if the cache is MAX_CACHE_SIZE + 2
  try {
    const snap = await cache.count().get()
    if (snap.data().count >= MAX_CACHE_SIZE) {
      // Delete the oldest entry.
      cache
        .orderBy('timestamp', 'desc')
        .limit(1)
        .get()
        .then((snapshot) => {
          snapshot.docs[0].ref.delete()
        })
    }
  } catch (error) {
    logger.error('cache error', {error})
  } finally {
    const trimmedText: string = text.trim().toLowerCase()
    logger.debug('cache text', trimmedText)
    cache.doc(trimmedText).set({
      embedding: embedding,
      timestamp: Timestamp.fromDate(new Date()),
    })
  }
}

/**
 * get the embedding from hugging face
 * @param {string} text the text to embed
 * @return {Promise<number[]>} the embedding
 **/
async function getHFembeddings(text: string): Promise<number[]> {
  const model = 'all-MiniLM-L6-v2'
  const apiUrl = `https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/${model}`
  const data = {inputs: text, wait_for_model: true}
  const hfToken: string | null = await getSecretKey('HF_API_KEY')
  let retries = 4
  while (retries > 0) {
    try {
      // call the api
      const response = await fetch(apiUrl, {
        headers: {
          Authorization: `Bearer ${hfToken}`,
          pragma: 'no-cache',
          'cache-control': 'no-cache',
        },
        method: 'POST',
        body: JSON.stringify(data),
      })
      const res = await response.json()
      if (res.error) {
        throw new Error(res.error)
      }
      return res as number[]
    } catch (error) {
      logger.warn('hf error', {error})
      retries--
      // wait 7 seconds
      await new Promise((resolve) => setTimeout(resolve, 7000))
    }
  }
  return []
}

/**
 * get the embedding from openai
 * @param {string} text the text to embed
 * @param {boolean} useCache whether to use the cache
 * @return {Promise<number[]>} the embedding
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */
async function getTextEmbedding(text: string, useCache: boolean) {
  // check if the text has already been cached
  const embeddings = useCache ? await getCachedTextSearch(text) : []
  if (embeddings.length === 0) {
    try {
      const vector: number[] = await getHFembeddings(text)
      if (useCache) {
        try {
          // cache the embedding
          cacheTextEmbedding(text, vector)
          return vector
        } catch (error) {
          logger.error('error getting embedding', error)
          return []
        }
      } else {
        return vector
      }
    } catch (error) {
      logger.error('API  error', {error})
      return []
    }
  }
  return embeddings
}

/**
 * get all notes for current user
 * @param {string} uid the user id
 * @return {Promise<QuerySnapshot>} the notes
 */
async function getMyNotes(uid: string): Promise<QuerySnapshot> {
  const userRef = getFirestore().collection('users').doc(uid)
  const res = await getFirestore().collection('notes').where('user', '==', userRef).get()
  return res
}

/**
 * get notes similar to a text query
 * @param {string} text the text to search for
 * @param {myNotes} notes the notes to search
 * @param {number} count the max number of notes to return
 * @return {string[]} ids of most similar notes sorted by similarity
 */
async function getSimilarToText(
  text: string,
  notes: QuerySnapshot<FirebaseFirestore.DocumentData>,
  count = 10
): Promise<NoteSummary[]> {
  const textVector: number[] = await getTextEmbedding(text, true)
  const similarNoteIds: NoteSummary[] = await vecSimilarRanked([textVector], notes, null, count)
  return similarNoteIds
}

/**
 * clean the HTM out of the snippet
 * @param {string} text the text to clean
 * @return {string} the cleaned text
 * @see https://www.npmjs.com/package/string-strip-html
 */
function cleanSnippet(text: string): string {
  // replace </p> with </p>. in the text
  // so sentences are delimed by periods
  text = text.replace(/<\/p>/g, '</p>.')

  // strip the html
  text = stripHtml(text, {
    ignoreTagsWithTheirContents: ['code'],
    stripTogetherWithTheirContents: ['button'],
    skipHtmlDecoding: true,
  }).result

  // replace any multiple periods with single periods
  text = text.replace(/\.{2,}/g, '. ')
  return text
}

type EmbeddingsRecord = { [id: string]: number[][] }
/**
 * get the 3 embeddings for a note title, snippet, comment
 * @param {string} noteSnapshot the note
 * @param {string} uid the user id
 * @return {EmbeddingsRecord} the embeddings
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */
export async function getNoteEmbeddings(
  noteSnapshot: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>
): Promise<EmbeddingsRecord> {
  const embeddingsSnap = await getFirestore().collection('embeddings').doc(noteSnapshot.id).get()
  let titleVector: number[]
  let commentVector: number[]
  let snippetVector: number[]
  if (embeddingsSnap.exists) {
    titleVector = embeddingsSnap.data()?.titleVector
    snippetVector = embeddingsSnap.data()?.snippetVector
    commentVector = embeddingsSnap.data()?.commentVector
  } else {
    const {title, snippet, comment} = noteSnapshot.data()
    const vecs = await updateNoteEmbeddings(title, comment, snippet, noteSnapshot.id)
    ;[titleVector, snippetVector, commentVector] = vecs
  }
  const dict: { [id: string]: number[][] } = {}
  dict[noteSnapshot.id] = [titleVector, snippetVector, commentVector]
  return dict
}

/**
 * get the 3 embeddings for a note title, snippet, comment
 * @param {string} title the note title
 * @param {string} comment the note comment
 * @param {string} snippet the note snippet
 * @param {string} noteId the note id
 * @return {number[][]} the embeddings
 * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
 */

export const updateNoteEmbeddings = async (
  title: string,
  comment: string,
  snippet: string,
  noteId: string
): Promise<number[][]> => {
  if (!(title || snippet || comment)) {
    return []
  }

  const updates: { [id: string]: number[] } = {}

  if (title) {
    updates['titleVector'] = await getTextEmbedding(title, false)
  }

  if (snippet) {
    const clean = cleanSnippet(snippet)
    updates['snippetVector'] = await getTextEmbedding(clean, false)
  }

  if (comment) {
    updates['commentVector'] = await getTextEmbedding(comment, false)
  }

  logger.debug('updateNoteEmbeddings', noteId)
  // write any updates to the db
  await getFirestore().collection('embeddings').doc(noteId).set(updates, {merge: true})

  return [updates['titleVector'], updates['snippetVector'], updates['commentVector']]
}

/**
 * for a note with embs 'noteVecs', calculate the similarity with searchVecs
 * @param {number[]} noteVecs the embeddings of the note
 * @param {number[]} searchVecs the embeddings of the search query
 * @return {number} the max similarity between them
 */
function getNoteSimilarity(noteVecs: number[][], searchVecs: number[][]): number {
  let maxSimilarity = 0.0
  // if seasrchVecs has only one vector, repeat it for each noteVec
  // this happens wehn the searchVec is from a text search
  if (searchVecs.length == 1) {
    searchVecs = Array(noteVecs.length).fill(searchVecs[0])
  }
  // if there are embeddings and the search vector has embeddings
  for (let idx = 0; idx <= noteVecs.length; idx++) {
    // check the jth element of note- and search-Vecs both have embeddings
    if (noteVecs[idx] && noteVecs[idx].length && searchVecs[idx] && searchVecs[idx].length) {
      const cosDistance: number = similarity(noteVecs[idx], searchVecs[idx]) ?? 0.0
      maxSimilarity = Math.max(maxSimilarity, cosDistance)
    }
  }
  return maxSimilarity
}

/**
 * cache the related notes to the original note
 * @param {string[]} rankedNotes the ranked notes
 * @param {dict[]} related the related notes
 * @param {string} originalId the id of the original note
 * @return {void}
 **/
function cacheRelated(rankedNotes: string[], related: NoteSummary[], originalId: string) {
  const now = Timestamp.fromDate(new Date())

  logger.debug('cacheRelated', originalId)
  // update the related notes for the original note
  // create an array of dicts with id and title for the db
  const relatedMap = related.map((note) => ({id: note[0], title: note[1]}))
  getFirestore().collection('notes').doc(originalId).set(
    {
      related: relatedMap,
      relatedUpdated: now,
    },
    {merge: true}
  )
}

/**
 * get the 10 most similar notes to a search vector
 * @param {Array<number[]>} searchVecs array of the vectors to search for
 * (eg title, snippet, comment), or maybe just one
 * @param {QueryDocumentSnapshot[]} notes the notes to search through
 * @param {string} originalId the id of the note we are searching for, or null
 * @param {number} count the number of notes to return
 * @param {number} threshold the minimum similarity score to return
 * @return {NoteSummary[]} ids of most similar notes sorted by similarity
 */
async function vecSimilarRanked(
  searchVecs: number[][],
  notes: QuerySnapshot,
  originalId: string | null,
  count = 10,
  threshold = THRESHOLD
): Promise<NoteSummary[]> {
  const promises: Promise<object>[] = []
  for (const n of notes.docs) {
    if (n.id != originalId) {
      promises.push(getNoteEmbeddings(n))
    }
  }
  const vecMaps = await Promise.all(promises)
  // make a single dict of all the embeddings
  const vecs: { [id: string]: number[][] } = {}
  for (const vecMap of vecMaps) {
    vecs[Object.keys(vecMap)[0]] = Object.values(vecMap)[0]
  }
  // vecs is now 3 embeddings for each note
  // we have all the results, now calculate the similarity
  const similarityScores: Record<string, number> = {} // id: score
  // eslint-disable-next-line guard-for-in
  for (const id in vecs) {
    // for a note with embs 'noteVec', calculate the similarity
    const score = getNoteSimilarity(vecs[id], searchVecs)
    console.log(`Similarity score : ${score} for ${id} v. ${originalId}`)
    if (score > threshold) {
      similarityScores[id] = score
    }
  }
  // Sort score scores in descending order
  // -> list of [id, score]
  const sortedScores = Object.entries(similarityScores).sort((a, b) => b[1] - a[1])

  // Retrieve the top 'count' notes
  // -> list of ids
  const rankedNotes = sortedScores.slice(0, count).map((score) => score[0])

  // const related = rankedNotes.map((id) => {
  //   return {
  //     id,
  //     title: notes.docs.find((n) => n.id == id)?.data().title ?? '',
  //   }
  // })

  const related: NoteSummary[] = []
  for (const id of rankedNotes) {
    const title = notes.docs.find((n) => n.id == id)?.data().title ?? ''
    related.push([id, title])
  }
  // cache the related notes to the original note
  if (originalId) {
    // get an array of {id, title, updated} for the related notes
    cacheRelated(rankedNotes, related, originalId)
  }
  return related
}

/**
 * search for text in the notes
 * @param {string} searchText the text to search for
 * @param {number} maxResults the maximum number of results to return
 * @param {string} uid the user id
 * @return {object[]} the most similar notes sorted by similarity {id: title}
 */
export const doTextSearch = async function(searchText: string, maxResults: number, uid: string): Promise<object[]> {
  const notes: QuerySnapshot = await getMyNotes(uid)
  const results: NoteSummary[] = []

  if (notes.docs.length == 0) {
    logger.debug('textSearch - no notes', uid)
    return results
  }

  // crude text search
  const searchTextLower = searchText.toLowerCase()
  for (const snap of notes.docs) {
    const note = snap.data()
    if (
      note.title.toLowerCase().includes(searchTextLower) ||
      note.comment.toLowerCase().includes(searchTextLower) ||
      note.snippet.toLowerCase().includes(searchTextLower)
    ) {
      results.push([snap.id, note.title])
    }
  }

  // if we still don't have enough results, search for similar notes
  if (Object.keys(results).length < maxResults) {
    const searchResults = await getSimilarToText(searchText, notes, maxResults - Object.keys(results).length)
    for (const r of searchResults) {
      // only add if the key not already in the list
      if (!results.some((e) => e[0] == r[0])) {
        results.push([r[0], r[1]])
      }
    }
  }

  return noteSummariesToIds(results)
}

/** FUNCTION: search for text in the notes
 * @param {object} req - The parameters Object.
 * @param {string} req.searchText - The search text.
 * @param {number} req.maxResults - The maximum number of results.
 * @return {QuerySnapshot[]} the most similar notes sorted by similarity
 */
export const textSearch = onCall(async (req) => {
  const {searchText, maxResults} = req.data
  const uid = req.auth?.uid
  return exports.doTextSearch(searchText, maxResults, uid)
})

/**
 * search for text in the notes
 * @param {string} noteId - ID of the note to compare
 * @param {number} maxResults - The maximum number of results.
 * @param {string} uid - The user id.
 * @param {number} threshold - The minimum similarity score to return.
 * @return {object[]} the most similar notes sorted by similarity
 */
export const doNoteSearch = async function(
  noteId: string,
  maxResults: number,
  uid: string,
  threshold = THRESHOLD
): Promise<object[]> {
  // get the note
  const notes = await getMyNotes(uid)
  // find the note with note.id == noteId
  const note = notes.docs.find((n) => n.id == noteId)
  if (!note) {
    logger.error('noteSearch - note not found', {noteId, uid})
    return []
  }
  const {title, comment, snippet} = note.data()

  // only search if there are text fields
  if (title || comment || snippet) {
    // does the original note have a valid related cache?
    if (note.data().related && note.data().related.length) {
      const user = await getFirestore().collection('users').doc(uid).get()
      if (user.data()?.lastUpdated < note.data().relatedUpdated) {
        logger.debug('noteSearch - using cache', {
          uid,
          lastUpdated: user.data()?.lastUpdated,
          relatedUpdated: note.data().relatedUpdated,
        })
        return note.data().related
      }
    }

    logger.debug('noteSearch - getting related')
    // we didn't find a valid cache, so search for related notes

    // if the user has no other notes, return empty
    if (notes.docs.length <= 1) {
      return []
    }

    // get embeddings for this note
    const vector = await getNoteEmbeddings(note)

    // get the most similar notes
    const searchResults = await vecSimilarRanked(vector[noteId], notes, noteId, maxResults, threshold)
    return noteSummariesToIds(searchResults)
  } else {
    // if the note has no text fields, return empty
    return []
  }
}

/**
 * search for text in the notes
 * @param {object} req - The parameters Object.
 * @param {string} req.noteId - ID of the note to compare
 * @param {number} req.maxResults - The maximum number of results.
 * @return {Array<{id, title}>} the most similar notes sorted by similarity
 */
export const noteSearch = onCall(async (req) => {
  const {noteId, maxResults, threshold} = req.data
  const uid = req.auth?.uid

  return exports.doNoteSearch(noteId, maxResults, uid, threshold)
})

// eslint-disable-next-line valid-jsdoc
/**
 * Firestore on-create trigger
 * Set the embeddings for a new note
 */
export const createNote = onDocumentCreated('notes/{noteId}', (event) => {
  // Get an object representing the document
  try {
    const newValue = event.data
    if (newValue === null || !event.data) {
      return 'No value'
    }
    getFirestore()
      .collection('notes')
      .doc(event.params.noteId)
      .set(
        {
          updatedAt: Timestamp.fromDate(new Date()),
        },
        {merge: true}
      )
      .catch((e) => {
        logger.error('note onCreated - error updating note', e)
        return false
      })
    // record the update time to the user record
    const now = Timestamp.fromDate(new Date())
    const data = event.data.data()
    getFirestore().collection('users').doc(data.user.id).update({
      lastUpdated: now,
    })

    updateNoteEmbeddings(
      newValue?.data().title,
      newValue?.data().comment,
      newValue?.data().snippet,
      event.params.noteId
    )
    return 'OK'
  } catch (error) {
    logger.error('note onCreated - error', error)
    return []
  }
})

/**
 * Firestore on-delete trigger
 * Remove the embeddings for a deleted note
 */
export const deleteNote = onDocumentDeleted('notes/{noteId}', (event) => {
  // record the update time to the user record
  const now = Timestamp.fromDate(new Date())
  getFirestore().collection('users').doc(event.data?.data().user.id).update({
    lastUpdated: now,
  })

  // delete the note embeddings
  return getFirestore().collection('embeddings').doc(event.params.noteId).delete()
})

/**
 * Firestore on-update trigger
 * Update the embeddings for a note
 */
export const updateNote = onDocumentUpdated('notes/{noteId}', (event) => {
  try {
    // Get an object representing the document
    const newValue = event.data?.after.data()

    // and the previous value before this update
    const previousValue = event.data?.before.data()

    // we will pass either the changed title, comment or snippet or nulls
    const titleChange = newValue?.title != previousValue?.title ? newValue?.title : null
    const commentChange = newValue?.comment != previousValue?.comment ? newValue?.comment : null
    const snippetChange = newValue?.snippet != previousValue?.snippet ? newValue?.snippet : null

    // don't update if ~now already to avoid recursion
    const now = Timestamp.fromDate(new Date()).toMillis()
    // 500ms since last update? ignore
    if (titleChange || commentChange || snippetChange) {
      const eventTs: number = event.data?.before.data().updatedAt
      if (now - eventTs > 500) {
        event.data?.after.ref
          .set(
            {
              updatedAt: Timestamp.fromDate(new Date()),
            },
            {merge: true}
          )
          .catch((e) => {
            logger.error('note onUpdate - error updating note', e)
            return false
          })

        logger.debug('note onUpdate - updating user lastUpdated', {
          titleChange,
          commentChange,
          snippetChange,
        })
        // record the update time to the user record
        getFirestore().collection('users').doc(newValue?.user.id).update({
          lastUpdated: now,
        })
      }
      logger.debug('note onUpdate - updating embeddings', event.params.noteId)
      updateNoteEmbeddings(titleChange, commentChange, snippetChange, event.params.noteId)
      return 'OK'
    } else {
      return []
    }
  } catch (error) {
    logger.error('note onUpdate - error', error)
    return []
  }
})
