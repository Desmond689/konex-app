import 'app_exception.dart';

class StorageException extends AppException {
  final String? bucketName;

  const StorageException({
    required super.message,
    this.bucketName,
    super.code,
    super.cause,
  });
}
