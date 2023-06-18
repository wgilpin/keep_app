import {getFirestore, Timestamp} from 'firebase-admin/firestore'
import {logger} from 'firebase-functions'
import {onDocumentCreated, onDocumentUpdated, onDocumentDeleted} from 'firebase-functions/v2/firestore'
import {updateNoteEmbeddings} from './embeddings_functions'

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
          lastUpdated: Timestamp.now(),
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

