/// Simple Result type for repository/use-case return values.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(Object error, StackTrace? stack) failure,
  }) {
    return switch (this) {
      Success(:final value) => success(value),
      Failure(:final error, :final stackTrace) => failure(error, stackTrace),
    };
  }
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final Object error;
  final StackTrace? stackTrace;
  const Failure(this.error, [this.stackTrace]);
}
