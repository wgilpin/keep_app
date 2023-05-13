import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages

class FirestoreDB {
  FirestoreDB([FirebaseFirestore? firestore])
      : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;

  // Stream<List<Review>> reviewsForUserStream() {
  //   debugPrint('in reviewsForUserStream');
  //   return firestore
  //       .collectionGroup('reviews')
  //       .where('user', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
  //       .snapshots()
  //       .map((QuerySnapshot query) {
  //     List<Review> reviews = [];
  //     for (var review in query.docs) {
  //       final reviewModel = Review.fromSnapshot(review);
  //       reviews.add(reviewModel);
  //     }

  //     debugPrint('review stream:${reviews.length}');
  //     return reviews;
  //   });
  // }

  // Future<void> addMovie(Show movie) async {
  //   var showsSnap = await firestore.collection('movies').doc(movie.id).get();
  //   if (!showsSnap.exists) {
  //     firestore.collection('movies').doc(movie.id).set({
  //       'title': movie.title,
  //       'posterPath': movie.posterPath,
  //       'genre_ids': movie.genreIds,
  //     });
  //   }
  // }

}
