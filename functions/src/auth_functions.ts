import * as firebaseFunctions from 'firebase-functions'
import {getFirestore, Timestamp} from 'firebase-admin/firestore'
import {logger} from 'firebase-functions'


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
