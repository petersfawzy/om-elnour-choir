import 'package:equatable/equatable.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';

abstract class HymnsState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// ✅ **الحالة الابتدائية**
class InitHymnsStates extends HymnsState {}

/// ⏳ **حالة تحميل البيانات**
class HymnsLoading extends HymnsState {}

/// ✅ **حالة تحميل الترانيم بنجاح**
class HymnsLoaded extends HymnsState {
  final List<HymnsModel> hymns;
  HymnsLoaded(this.hymns);

  @override
  List<Object?> get props => [hymns];
}

/// ❌ **حالة الخطأ**
class HymnsErrorState extends HymnsState {
  final String errorMessage;
  HymnsErrorState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

/// 🎵 **حالة تشغيل آخر ترنيمة مشغلة**
class HymnsLastPlayed extends HymnsState {
  final int index;
  final String title;
  final String url;
  final Duration position;
  final bool isPlaying;

  HymnsLastPlayed(
      this.index, this.title, this.url, this.position, this.isPlaying);

  @override
  List<Object?> get props => [index, title, url, position, isPlaying];
}

/// 🎚 **تحديث موضع الـ Seek Bar**
class HymnsSeekBarUpdated extends HymnsState {
  final Duration position;
  HymnsSeekBarUpdated(this.position);

  @override
  List<Object?> get props => [position];
}

/// ✅ **حالة نجاح إضافة ترنيمة جديدة**
class CreateHymnSuccessState extends HymnsState {}

/// ✅ **حالة نجاح تعديل ترنيمة**
class EditHymnSuccessState extends HymnsState {}

/// ✅ **حالة نجاح حذف ترنيمة**
class DeleteHymnSuccessState extends HymnsState {}

/// 🎶 **حالة تشغيل ترنيمة سابقة**
class HymnsPlayPrevious extends HymnsState {}

/// 🔀 **حالة التبديل العشوائي**
class HymnsShuffleState extends HymnsState {
  final bool isShuffle;
  HymnsShuffleState(this.isShuffle);

  @override
  List<Object?> get props => [isShuffle];
}

/// ⏱ **حالة الموضع الحالي للترنيمة**
class HymnsCurrentPositionTextState extends HymnsState {
  final String currentPositionText;
  HymnsCurrentPositionTextState(this.currentPositionText);

  @override
  List<Object?> get props => [currentPositionText];
}

/// ⏳ **حالة المدة الكاملة للترنيمة**
class HymnsCurrentDurationState extends HymnsState {
  final String currentDuration;
  HymnsCurrentDurationState(this.currentDuration);

  @override
  List<Object?> get props => [currentDuration];
}

/// ⏭ **حالة الانتقال إلى موضع محدد**
class HymnsSeekToState extends HymnsState {
  final Duration seekToPosition;
  HymnsSeekToState(this.seekToPosition);

  @override
  List<Object?> get props => [seekToPosition];
}

/// 🕒 **حالة النص المدة الكاملة**
class HymnsDurationTextState extends HymnsState {
  final String durationText;
  HymnsDurationTextState(this.durationText);

  @override
  List<Object?> get props => [durationText];
}

/// 🔁 **حالة التكرار**
class HymnsLoopState extends HymnsState {
  final bool isLooping;
  HymnsLoopState(this.isLooping);

  @override
  List<Object?> get props => [isLooping];
}

/// ⏹ **حالة إيقاف التشغيل**
class HymnsStopped extends HymnsState {}

/// 📥 **حالة تحميل الترانيم باستخدام الكاش**
class HymnsCachedLoaded extends HymnsState {
  final List<HymnsModel> hymns;
  HymnsCachedLoaded(this.hymns);

  @override
  List<Object?> get props => [hymns];
}
