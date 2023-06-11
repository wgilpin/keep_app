import {getFirestore, DocumentSnapshot, QueryDocumentSnapshot} from 'firebase-admin/firestore'
import {logger} from 'firebase-functions'
// eslint-disable-next-line @typescript-eslint/no-var-requires
const similarity = require('compute-cosine-similarity')
import {stripHtml} from 'string-strip-html'
import {SecretManagerServiceClient} from '@google-cloud/secret-manager'
import {cacheTextEmbedding, getCachedTextSearch} from './search_functions'

const HF_SECRET_NAME = 'HF_API_KEY/versions/1'

let ApiKey: string | null = null

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
      const name = `projects/516790082055/secrets/${keyName}`
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
 * get the embedding from hugging face
 * @param {string} text the text to embed
 * @return {Promise<number[]>} the embedding
 **/
async function getHFembeddings(text: string): Promise<number[]> {
  const model = 'all-MiniLM-L6-v2'
  const apiUrl = `https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/${model}`
  const data = {inputs: text, wait_for_model: true}
  const hfToken: string | null = await getSecretKey(HF_SECRET_NAME)
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
export async function getTextEmbedding(text: string, useCache: boolean) {
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
   * check if the note has embeddings
   * @param {DocumentSnapshot} snap the snapshot of the note
   * @return {boolean} note has embeddings
   */
function hasEmbeddings(snap: DocumentSnapshot): boolean {
  if (!snap.exists) {
    return false
  }
  if (!snap.data()) {
    return false
  }
  if (snap.data()?.titleVector && snap.data()?.titleVector.length > 0) {
    return true
  }
  if (snap.data()?.snippetVector && snap.data()?.snippetVector.length > 0) {
    return true
  }
  if (snap.data()?.commentVector && snap.data()?.commentVector.length > 0) {
    return true
  }
  return false
}

/**
   * get the 3 embeddings for a note title, snippet, comment
   * @param {string} noteSnapshot the note
   * @param {string} uid the user id
   * @return {EmbeddingsRecord} the embeddings
   * @see https://beta.openai.com/docs/api-reference/retrieve-embedding
   */
export async function getNoteEmbeddings(
  noteSnapshot: QueryDocumentSnapshot
): Promise<EmbeddingsRecord> {
  const embeddingsSnap = await getFirestore().collection('embeddings').doc(noteSnapshot.id).get()
  let titleVector: number[]
  let commentVector: number[]
  let snippetVector: number[]
  if (hasEmbeddings(embeddingsSnap)) {
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
export function getNoteSimilarity(noteVecs: number[][], searchVecs: number[][]): number {
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
