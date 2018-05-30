// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

/// Fusion of physical file system and in-memory files, with just enough
/// functionality to use it in tests.
class FusionResourceProvider extends PhysicalResourceProvider {
  final MemoryResourceProvider memory = new MemoryResourceProvider();

  FusionResourceProvider() : super(null);

  @override
  File getFile(String path) {
    File file = memory.getFile(path);
    return file.exists ? file : super.getFile(path);
  }

  @override
  Folder getFolder(String path) {
    Folder folder = memory.getFolder(path);
    return folder.exists ? folder : super.getFolder(path);
  }

  @override
  Resource getResource(String path) {
    Resource resource = memory.getResource(path);
    return resource.exists ? resource : super.getResource(path);
  }
}
