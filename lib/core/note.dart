import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:gitjournal/utils/datetime.dart';

import 'note_fileName.dart';
import 'notes_folder.dart';
import 'serializers.dart';

enum NoteLoadState {
  None,
  Loading,
  Loaded,
  NotExists,
}

class Note with ChangeNotifier implements Comparable<Note> {
  NotesFolder parent;
  String _filePath;

  DateTime _created;
  DateTime _modified;
  NoteData _data = NoteData();

  DateTime _fileLastModified;

  var _loadState = NoteLoadState.None;
  var _serializer = MarkdownYAMLSerializer();

  Note(this.parent, this._filePath) {
    _created = DateTime(0, 0, 0, 0, 0, 0, 0, 0);
  }

  Note.newNote(this.parent) {
    _created = DateTime.now();
    _data.props['created'] = toIso8601WithTimezone(created);
    _filePath = p.join(parent.folderPath, getFileName(this));
  }

  String get filePath {
    return _filePath;
  }

  DateTime get created {
    return _created;
  }

  set created(DateTime dt) {
    _created = dt;

    if (hasValidDate()) {
      _data.props['created'] = toIso8601WithTimezone(created);
    } else {
      _data.props.remove('created');
    }
    notifyListeners();
  }

  DateTime get modified {
    return _modified;
  }

  set modified(DateTime dt) {
    _modified = dt;

    if (hasValidDate()) {
      _data.props['modified'] = toIso8601WithTimezone(_modified);
    } else {
      _data.props.remove('modified');
    }
    notifyListeners();
  }

  void updateModified() {
    modified = DateTime.now();
  }

  String get body {
    return data.body;
  }

  set body(String newBody) {
    data.body = newBody;
    notifyListeners();
  }

  NoteData get data {
    return _data;
  }

  set data(NoteData data) {
    _data = data;

    if (data.props.containsKey("created")) {
      var createdStr = data.props['created'].toString();
      try {
        _created = DateTime.parse(data.props['created']).toLocal();
      } catch (ex) {
        // Ignore it
      }

      if (_created == null) {
        var regex = RegExp(
            r"(\d{4})-(\d{2})-(\d{2})T(\d{2})\:(\d{2})\:(\d{2})\+(\d{2})\:(\d{2})");
        if (regex.hasMatch(createdStr)) {
          // FIXME: Handle the timezone!
          createdStr = createdStr.substring(0, 19);
          _created = DateTime.parse(createdStr);
        }
      }
    }

    _created ??= DateTime(0, 0, 0, 0, 0, 0, 0, 0);
    notifyListeners();
  }

  bool hasValidDate() {
    // Arbitrary number, when we set the year = 0, it becomes 1, somehow
    return created.year > 10;
  }

  bool isEmpty() {
    return body.isEmpty;
  }

  Future<NoteLoadState> load() async {
    if (_loadState == NoteLoadState.Loading) {
      return _loadState;
    }

    final file = File(filePath);
    if (_loadState == NoteLoadState.Loaded) {
      var fileLastModified = file.lastModifiedSync();
      if (fileLastModified == _fileLastModified) {
        return _loadState;
      }
    }

    if (!file.existsSync()) {
      _loadState = NoteLoadState.NotExists;
      notifyListeners();
      return _loadState;
    }

    final string = await file.readAsString();
    data = _serializer.decode(string);

    _fileLastModified = file.lastModifiedSync();
    _loadState = NoteLoadState.Loaded;

    notifyListeners();
    return _loadState;
  }

  // FIXME: What about error handling?
  Future<void> save() async {
    assert(filePath != null);
    assert(data != null);
    assert(data.body != null);
    assert(data.props != null);

    var file = File(filePath);
    var contents = _serializer.encode(data);
    await file.writeAsString(contents);
  }

  // FIXME: What about error handling?
  Future<void> remove() async {
    var file = File(filePath);
    await file.delete();
  }

  // FIXME: Can't this part be auto-generated?
  @override
  int get hashCode => filePath.hashCode ^ created.hashCode ^ data.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath &&
          data == other.data;

  @override
  String toString() {
    return 'Note{filePath: $filePath, created: $created, modified: $modified, data: $data}';
  }

  @override
  int compareTo(Note other) {
    if (other == null) {
      return -1;
    }
    if (other.modified == null && modified == null) {
      if (other.created == null && created == null) {
        return filePath.compareTo(other.filePath);
      }
      if (other.created == null) {
        return -1;
      } else if (created == null) {
        return 1;
      }

      return created.compareTo(other.created);
    }

    if (other.modified == null) {
      return -1;
    } else if (modified == null) {
      return 1;
    }

    return modified.compareTo(other.modified);
  }
}
