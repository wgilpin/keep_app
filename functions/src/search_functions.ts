import {QuerySnapshot, getFirestore, Timestamp} from 'firebase-admin/firestore'
import {onCall} from 'firebase-functions/v2/https'
import {logger} from 'firebase-functions'
import {EmbeddingsRecord, getNoteEmbeddings, getNoteSimilarity, getTextEmbedding} from './embeddings_functions'

const THRESHOLD = 0.2
const MAX_CACHE_SIZE = 20


// [id, title]
type NoteSummary = [string, string]

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
 * get the embedding from the cache if present
 * @param {string} text the text to find
 * @return {Promise<number[]>} the embedding
 **/
export async function getCachedTextSearch(text: string): Promise<number[]> {
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
export async function cacheTextEmbedding(text: string, embedding: number[]) {
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
 * get notes similar to a text query
 * @param {string} text the text to search for
 * @param {myNotes} notes the notes to search
 * @param {number} count the max number of notes to return
 * @return {string[]} ids of most similar notes sorted by similarity
 */
async function getSimilarToText(
  text: string,
  notes: QuerySnapshot,
  count = 10
): Promise<NoteSummary[]> {
  const textVector: number[] = await getTextEmbedding(text, true)
  const similarNoteIds: NoteSummary[] = await vecSimilarRanked([textVector], notes, null, count)
  return similarNoteIds
}


/**
 * cache the related notes to the original note
 * @param {dict[]} related the related notes
 * @param {string} originalId the id of the original note
 * @return {void}
 **/
function cacheRelated(related: NoteSummary[], originalId: string) {
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
  const vecs: EmbeddingsRecord = await getEmbeddingsForNotes(notes, originalId)
  // vecs is now 3 embeddings for each note
  // we have all the results, now calculate the similarity
  const similarityScores: Record<string, number> = {} // id: score
  // eslint-disable-next-line guard-for-in
  for (const id in vecs) {
    // for a note with embs 'noteVec', calculate the similarity
    const score = getNoteSimilarity(vecs[id], searchVecs)
    if (score <0.0000001) {
      logger.debug(`Similarity score : ${score} for ${id} v. ${originalId}`)
    }
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

  // prepare the return value
  const related: NoteSummary[] = []
  for (const id of rankedNotes) {
    const title = notes.docs.find((n) => n.id == id)?.data().title ?? ''
    related.push([id, title])
  }
  // cache the related notes to the original note
  if (originalId) {
    // get an array of {id, title, updated} for the related notes
    cacheRelated(related, originalId)
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
  if (!uid) {
    logger.debug('textSearch - uid not found')
    return []
  }
  return doTextSearch(searchText, maxResults, uid)
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
  if (!uid) {
    logger.error('noteSearch - no uid')
    return []
  }
  return doNoteSearch(noteId, maxResults, uid, threshold)
})


/**
 * get the embeddings for a list of notes
 * @param {DocumentSnapshot} notes the snapshot of the notes
 * @param {string} originalId the id of the note to exclude from the results
 * @return {object} the embeddings for the notes
 **/
async function getEmbeddingsForNotes(notes: QuerySnapshot<FirebaseFirestore.DocumentData>, originalId: string | null) {
  const promises: Promise<object>[] = []
  for (const n of notes.docs) {
    if (n.id != originalId) {
      promises.push(getNoteEmbeddings(n))
    }
  }
  const vecMaps = await Promise.all(promises)
  // make a single dict of all the embeddings
  const vecs: EmbeddingsRecord = {}
  for (const vecMap of vecMaps) {
    vecs[Object.keys(vecMap)[0]] = Object.values(vecMap)[0]
  }
  return vecs
}

