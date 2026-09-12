import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../domain/models/backup_archive.dart';

abstract interface class BackupFiles {
  Future<String?> pickBackup();

  /// False means the user cancelled. Only an explicit native picker selection
  /// can create/overwrite a file; the adapter never invents an output path.
  Future<bool> saveBackup(BackupArchive archive);
}

final class NativeBackupFiles implements BackupFiles {
  const NativeBackupFiles();
  @override
  Future<String?> pickBackup() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a Deal Finder backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
      windowsOptions: const WindowsOptions(lockParentWindow: true),
    );
    if (file == null) return null;
    final length = file.lengthSync();
    if (length != null && length > BackupArchive.maxBytes) {
      throw const FormatException('Backup exceeds the 32 MiB limit.');
    }
    return readBackupText(file.readAsByteStream());
  }

  @override
  Future<bool> saveBackup(BackupArchive archive) async =>
      await FilePicker.saveFile(
        fileName:
            'deal-finder-${archive.createdAt.toUtc().toIso8601String().replaceAll(':', '-')}.json',
        bytes: Uint8List.fromList(utf8.encode(archive.encode())),
        mimeType: 'application/json',
        dialogTitle: 'Save Deal Finder backup',
        windowsOptions: const WindowsOptions(lockParentWindow: true),
      ) !=
      null;
}

/// The declared file size is advisory: enforce the cap again on actual bytes.
Future<String> readBackupText(Stream<List<int>> stream) async {
  final bytes = BytesBuilder(copy: false);
  final completed = Completer<void>();
  void fail(Object error) {
    if (!completed.isCompleted) completed.completeError(error);
  }

  final deadline = Timer(
    const Duration(seconds: 30),
    () => fail(TimeoutException('Reading the backup took too long.')),
  );
  final subscription = stream.listen(
    (chunk) {
      if (completed.isCompleted) return;
      if (bytes.length + chunk.length > BackupArchive.maxBytes) {
        fail(const FormatException('Backup exceeds the 32 MiB limit.'));
      } else {
        bytes.add(chunk);
      }
    },
    onError: (Object error) => fail(error),
    onDone: () {
      if (!completed.isCompleted) completed.complete();
    },
  );
  try {
    await completed.future;
    return utf8.decode(bytes.takeBytes());
  } on FormatException catch (error) {
    if (error.message == 'Backup exceeds the 32 MiB limit.') rethrow;
    throw const FormatException('Backup is not valid UTF-8 text.');
  } finally {
    deadline.cancel();
    await subscription.cancel();
  }
}
