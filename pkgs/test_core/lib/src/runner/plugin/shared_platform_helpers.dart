// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

/// Converts a raw [Socket] into a [StreamChannel] of JSON objects.
///
/// JSON messages are separated by newlines.
StreamChannel<Object?> jsonSocketStreamChannel(Socket socket) =>
    StreamChannel.withGuarantees(socket, socket)
        .cast<List<int>>()
        .transform(StreamChannelTransformer.fromCodec(utf8))
        .transformStream(const LineSplitter())
        .transformSink(StreamSinkTransformer.fromHandlers(
            handleData: (original, sink) => sink.add('$original\n')))
        .transform(jsonDocument);
