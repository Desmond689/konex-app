import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:konex/core/errors/auth_exception.dart';
import 'package:konex/core/errors/error_handler.dart';
import 'package:konex/core/errors/network_exception.dart';

void main() {
  group('ErrorHandler', () {
    test('maps invalid credentials to auth exception, not network error', () {
      final result = ErrorHandler.map('Invalid login credentials');

      expect(result, isA<AuthException>());
      expect(result.code, 'invalid_credentials');
      expect(result.message, 'Invalid email or password.');
    });

    test('maps true offline socket to no_connection', () {
      final result = ErrorHandler.map(
        const SocketException('Network is unreachable'),
      );

      expect(result, isA<NetworkException>());
      expect(result.code, 'no_connection');
    });

    test('maps host lookup failure to server_unreachable, not no_connection',
        () {
      final result = ErrorHandler.map(
        const SocketException('Failed host lookup: xyz.supabase.co'),
      );

      expect(result, isA<NetworkException>());
      expect(result.code, 'server_unreachable');
      expect(result.message, contains('Unable to reach the server'));
    });

    test('maps connection refused to server_unreachable', () {
      final result = ErrorHandler.map(
        const SocketException('Connection refused'),
      );

      expect(result, isA<NetworkException>());
      expect(result.code, 'server_unreachable');
    });

    test('maps timeout strings to timeout', () {
      final result = ErrorHandler.map('Request timed out');

      expect(result, isA<NetworkException>());
      expect(result.code, 'timeout');
    });

    test('maps user already registered', () {
      final result = ErrorHandler.map('User already registered');

      expect(result, isA<AuthException>());
      expect(result.code, 'user_exists');
    });

    test('maps email not confirmed', () {
      final result = ErrorHandler.map('Email not confirmed');

      expect(result, isA<AuthException>());
      expect(result.code, 'email_not_confirmed');
    });
  });
}
