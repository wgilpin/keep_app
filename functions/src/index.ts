// Description: This file is the entry point for all the cloud functions.

import {initializeApp} from 'firebase-admin/app'

initializeApp()

// google cloud functions
import {setupNewUser} from './auth_functions'
export {setupNewUser}

import {createNote, deleteNote, updateNote} from './firestore_functions'
export {createNote, deleteNote, updateNote}

import {textSearch, noteSearch, doNoteSearch, doTextSearch} from './search_functions'
export {textSearch, noteSearch}

// for testing only
import {getNoteEmbeddings, updateNoteEmbeddings} from './embeddings_functions'
export {getNoteEmbeddings, updateNoteEmbeddings}

export {doNoteSearch, doTextSearch}


