// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'select_project_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SelectProjectState {

 String get path;
/// Create a copy of SelectProjectState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SelectProjectStateCopyWith<SelectProjectState> get copyWith => _$SelectProjectStateCopyWithImpl<SelectProjectState>(this as SelectProjectState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SelectProjectState&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'SelectProjectState(path: $path)';
}


}

/// @nodoc
abstract mixin class $SelectProjectStateCopyWith<$Res>  {
  factory $SelectProjectStateCopyWith(SelectProjectState value, $Res Function(SelectProjectState) _then) = _$SelectProjectStateCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$SelectProjectStateCopyWithImpl<$Res>
    implements $SelectProjectStateCopyWith<$Res> {
  _$SelectProjectStateCopyWithImpl(this._self, this._then);

  final SelectProjectState _self;
  final $Res Function(SelectProjectState) _then;

/// Create a copy of SelectProjectState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SelectProjectState].
extension SelectProjectStatePatterns on SelectProjectState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SelectProjectState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SelectProjectState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SelectProjectState value)  $default,){
final _that = this;
switch (_that) {
case _SelectProjectState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SelectProjectState value)?  $default,){
final _that = this;
switch (_that) {
case _SelectProjectState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SelectProjectState() when $default != null:
return $default(_that.path);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path)  $default,) {final _that = this;
switch (_that) {
case _SelectProjectState():
return $default(_that.path);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path)?  $default,) {final _that = this;
switch (_that) {
case _SelectProjectState() when $default != null:
return $default(_that.path);case _:
  return null;

}
}

}

/// @nodoc


class _SelectProjectState implements SelectProjectState {
   _SelectProjectState({this.path = ''});
  

@override@JsonKey() final  String path;

/// Create a copy of SelectProjectState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SelectProjectStateCopyWith<_SelectProjectState> get copyWith => __$SelectProjectStateCopyWithImpl<_SelectProjectState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SelectProjectState&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'SelectProjectState(path: $path)';
}


}

/// @nodoc
abstract mixin class _$SelectProjectStateCopyWith<$Res> implements $SelectProjectStateCopyWith<$Res> {
  factory _$SelectProjectStateCopyWith(_SelectProjectState value, $Res Function(_SelectProjectState) _then) = __$SelectProjectStateCopyWithImpl;
@override @useResult
$Res call({
 String path
});




}
/// @nodoc
class __$SelectProjectStateCopyWithImpl<$Res>
    implements _$SelectProjectStateCopyWith<$Res> {
  __$SelectProjectStateCopyWithImpl(this._self, this._then);

  final _SelectProjectState _self;
  final $Res Function(_SelectProjectState) _then;

/// Create a copy of SelectProjectState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(_SelectProjectState(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
