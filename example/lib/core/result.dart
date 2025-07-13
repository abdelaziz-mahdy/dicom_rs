/// Safe result type for error handling
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final String error;
  final StackTrace? stackTrace;
}

/// Extension methods for Result
extension ResultExtensions<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  
  T? get dataOrNull => switch (this) {
    Success<T> success => success.data,
    Failure<T> _ => null,
  };
  
  String? get errorOrNull => switch (this) {
    Success<T> _ => null,
    Failure<T> failure => failure.error,
  };
  
  R fold<R>(R Function(T data) onSuccess, R Function(String error) onFailure) {
    return switch (this) {
      Success<T> success => onSuccess(success.data),
      Failure<T> failure => onFailure(failure.error),
    };
  }
}